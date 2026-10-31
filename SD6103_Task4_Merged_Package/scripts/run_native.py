#!/usr/bin/env python3
import argparse, csv, datetime, hashlib, json, math, os, platform, statistics, time  # Record reproducible inputs and measurements.
from decimal import Decimal  # Preserve exact PostgreSQL numeric values in result exports.
from pathlib import Path  # Resolve the delivered package independently of the working directory.

ROOT = Path(__file__).resolve().parents[1]  # Locate the portable project root.
TABLES = ['town','hdb_flat','resale_transaction','hawker_centre','proximity_level','nearby']  # Load the six merged base relations.
FIELDS = ['phase','configuration','size_level','transaction_rows','active_table_bytes','query_no','repetition','execution_ms','planning_ms','result_rows','sql_sha256']  # Match the WASM evidence format.
parser = argparse.ArgumentParser(description='Fresh, isolated native PostgreSQL Task 3 and Task 4 experiment.')  # Document the command entry point.
parser.add_argument('--dsn',default='',help='libpq connection string; default uses PGHOST/PGPORT/PGDATABASE/PGUSER and .pgpass.')  # Keep credentials outside source files.
parser.add_argument('--output',type=Path,required=True,help='New empty evidence directory.')  # Prevent accidental evidence replacement.
args = parser.parse_args()  # Read explicit run settings; --help works before installing optional drivers.
import psycopg  # Connect to a real PostgreSQL server; install the declared binary extra.
from psycopg.rows import dict_row  # Preserve returned column names in complete results.
out = args.output.resolve()  # Freeze an absolute output location.
if out.exists() and any(out.iterdir()): raise SystemExit('Output must be new or empty; earlier observations are never overwritten.')  # Protect completed and partial runs.
for sub in ['', 'results', 'plans', 'configurations', 'sql_used']: (out/sub).mkdir(parents=True,exist_ok=True)  # Create auditable evidence locations.
data = ROOT/'data/processed'  # Use the delivered, audited 2023–2025 data.
specs = json.loads((ROOT/'sql/05_index_candidates.json').read_text())  # Share candidate definitions with the WASM runner.
manifest = json.loads((data/'data_manifest.json').read_text())  # Verify each actual cumulative load.
queries = {q:(ROOT/f'sql/queries/Q{q}.sql').read_text() for q in range(1,7)}  # Time exactly the report's full SELECT statements.
sha = lambda s: hashlib.sha256(s.encode()).hexdigest()  # Fingerprint exact SQL text.
save = lambda n,v: (out/n).write_text(json.dumps(v,indent=2,default=str),encoding='utf-8')  # Persist structured evidence without losing decimal text.
for q,s in queries.items(): (out/f'sql_used/Q{q}.sql').write_text(s)  # Freeze all measured queries.
schema = 'sd6103_'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d_%H%M%S')+'_'+os.urandom(3).hex()  # Allocate a fresh schema; never delete housing.
raw, sizes, candidates, baseline_fingerprints, row_counts = [], [], [], {}, {}  # Keep one traceable experiment state.

def csv_export(name, rows, columns):  # Export complete result tables and raw timing evidence.
    with (out/name).open('w',newline='',encoding='utf-8') as f:  # Preserve spreadsheet-compatible UTF-8 CSV.
        w=csv.DictWriter(f,fieldnames=columns); w.writeheader(); w.writerows(rows)  # Retain explicit column order.

def fingerprint(rows):  # Compare values independently of presentation order.
    return sha(json.dumps(sorted([sorted((k,None if v is None else str(v)) for k,v in r.items()) for r in rows],key=str),default=str))  # Reject any changed group or value.

with psycopg.connect(args.dsn,autocommit=True,row_factory=dict_row) as conn:  # Use the selected server with explicit maintenance transactions.
    def query(sql, params=None):  # Execute one complete SQL statement.
        with conn.cursor() as cur:  # Release server-side cursor resources promptly.
            cur.execute(sql,params); return cur.fetchall() if cur.description else []  # Return real result columns without COUNT wrappers.

    def copy(table,file):  # Bulk-load CSV with an explicit header-derived column list.
        with (data/file).open('r',encoding='utf-8',newline='') as source: columns=next(csv.reader(source))  # Respect the merged transaction column order.
        if not all(c.replace('_','').isalpha() for c in columns): raise ValueError('Unexpected CSV column')  # Reject untrusted identifier syntax.
        with conn.cursor() as cur, cur.copy(f'COPY {schema}.{table} ({",".join(columns)}) FROM STDIN WITH (FORMAT CSV,HEADER TRUE)') as target:  # Use client-side portable COPY.
            with (data/file).open('rb') as source:  # Stream rather than embed large SQL literals.
                while block:=source.read(1024*1024): target.write(block)  # Keep memory bounded.

    def footprints():  # Capture real server relation sizes for all six relations.
        return [dict(table=t,**query(f"SELECT count(*)::integer AS rows,pg_total_relation_size('{schema}.{t}')::bigint AS bytes FROM {schema}.{t}")[0]) for t in TABLES]  # Include constraint indexes and actual table storage.

    def inventory():  # Record indexes before every experiment.
        return query("SELECT tablename,indexname,indexdef,pg_relation_size((schemaname||'.'||indexname)::regclass)::bigint AS bytes FROM pg_indexes WHERE schemaname=%s ORDER BY tablename,indexname",(schema,))  # Separate t4 indexes from constraint indexes.

    def nodes(plan):  # Extract operators used to explain measured behaviour.
        keys=['Node Type','Relation Name','Index Name','Actual Rows','Actual Loops','Heap Fetches','Sort Method','Sort Space Used','Sort Space Type','Shared Hit Blocks','Shared Read Blocks','Temp Read Blocks','Temp Written Blocks']  # Retain actual execution details.
        return [{k:plan[k] for k in keys if k in plan}]+[n for child in plan.get('Plans',[]) for n in nodes(child)]  # Visit every nested node.

    def measure(phase,config,size,n,check=False):  # Keep queries, warm-up and five-repeat protocol identical across configurations.
        counts=footprints(); indexes=inventory(); plans=[]  # Collect untimed database state.
        save(f'configurations/{config}_S{size}_indexes.json',indexes)  # Prove which optional indexes actually existed.
        row_counts[f'{config}_S{size}']={}  # Track group counts independently of executor timings.
        for q,s in queries.items():  # Export all calculated fields before measurement.
            rows=query(s); digest=fingerprint(rows); row_counts[f'{config}_S{size}'][q]=len(rows)  # Validate complete outputs.
            if check and digest!=baseline_fingerprints[q]: raise ValueError(f'Changed output: {config} Q{q}')  # Stop on semantic drift.
            if config=='baseline' and size==5: baseline_fingerprints[q]=digest  # Establish the largest-data Task 3 reference.
            save(f'results/{config}_S{size}_Q{q}.json',{'rows':rows})  # Preserve full query evidence.
            csv_export(f'results/{config}_S{size}_Q{q}.csv',rows,list(rows[0]) if rows else [])  # Include every result, rather than an excerpt.
        for s in queries.values(): query('EXPLAIN (ANALYZE,BUFFERS,TIMING OFF,FORMAT JSON) '+s)  # Exclude one full-query warm-up.
        for rep in range(1,6):  # Record exactly five repeats per query/configuration.
            for q in [(k+size+rep)%6+1 for k in range(6)]:  # Rotate query order without altering individual SELECTs.
                plan=query('EXPLAIN (ANALYZE,BUFFERS,TIMING OFF,FORMAT JSON) '+queries[q])[0]['QUERY PLAN'][0]  # Separate executor time from planning and client transfer.
                save(f'plans/{config}_S{size}_Q{q}_R{rep}.json',plan)  # Retain all actual timed plans.
                if rep==1: plans.append({'query_no':q,'execution_ms':plan['Execution Time'],'nodes':nodes(plan['Plan'])})  # Summarize a reproducible representative plan.
                raw.append(dict(phase=phase,configuration=config,size_level=size,transaction_rows=n,active_table_bytes=sum(t['bytes'] for t in counts),query_no=q,repetition=rep,execution_ms=plan['Execution Time'],planning_ms=plan['Planning Time'],result_rows=plan['Plan']['Actual Rows'],sql_sha256=sha(queries[q])))  # Save full provenance with each time.
                csv_export('measurements_raw.csv',raw,FIELDS)  # Flush observations after every successful query.
        save(f'configurations/{config}_S{size}_plans.json',plans)  # Link narrative plan evidence to raw JSON plans.
        return dict(means=[statistics.mean(r['execution_ms'] for r in raw if r['configuration']==config and r['size_level']==size and r['query_no']==q) for q in range(1,7)],plans=plans,indexes=indexes)  # Compute measured means only.

    def drop_optional():  # Restore the constraint-only baseline between isolated trials.
        for i in inventory():  # Inspect the current isolated schema only.
            if i['indexname'].startswith('t4_'): query(f'DROP INDEX {schema}.{i["indexname"]}')  # Preserve every PK, unique and exclusion index.

    def build(statements):  # Measure build cost outside SELECT timing.
        started=time.perf_counter()  # Start a separate wall-clock index-build measurement.
        for statement in statements: query(statement)  # Apply the shared candidate DDL.
        return dict(build_wall_ms=(time.perf_counter()-started)*1000,extra_index_bytes=sum(i['bytes'] for i in inventory() if i['indexname'].startswith('t4_')))  # Report storage and maintenance trade-offs.

    ddl=(ROOT/'sql/01_schema.sql').read_text().replace('housing',schema)  # Redirect DDL to the newly allocated schema.
    query(ddl)  # Fail on a collision rather than dropping an existing schema.
    query(f'SET search_path = {schema}, public')  # Keep the exact unqualified query text unchanged.
    for t in TABLES:  # Keep dimensions fixed while growing transactions.
        if t!='resale_transaction': copy(t,f'{t}.csv'); query(f'VACUUM (ANALYZE) {t}')  # Apply equal visibility maintenance to reference tables.
    environment=dict(version=query('SELECT version() AS v')[0]['v'],runtime='Native PostgreSQL server',schema=schema,client_platform=platform.platform(),client_python=platform.python_version(),captured_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),server_hardware='Record separately if the server is remote.',metric='EXPLAIN (ANALYZE,BUFFERS,TIMING OFF,FORMAT JSON) Execution Time',sql_sha256={q:sha(s) for q,s in queries.items()})  # Avoid mislabelling client hardware as server hardware.
    environment['settings']=query("SELECT name,setting,unit FROM pg_settings WHERE name IN ('work_mem','shared_buffers','max_parallel_workers_per_gather','jit','enable_seqscan','enable_indexscan','enable_indexonlyscan') ORDER BY name")  # Record actual server planner settings.
    save('environment.json',environment)  # Persist runtime provenance before experiments.
    for size in range(1,6):  # Reproduce all five fixed-period cumulative partitions.
        copy('resale_transaction',f'transactions_part{size}.csv'); query('VACUUM (ANALYZE) resale_transaction')  # Maintain baseline and index visibility equally.
        counts=footprints(); n=next(t['rows'] for t in counts if t['table']=='resale_transaction')  # Read the true loaded population.
        if n!=manifest['stages'][size-1]['transaction_rows']: raise ValueError('Unexpected cumulative row count')  # Reject incomplete data loads.
        if any(i['indexname'].startswith('t4_') for i in inventory()): raise ValueError('Contaminated Task 3 baseline')  # Detect premature analytical indexes.
        sizes.append(dict(size_level=size,transaction_rows=n,tables=counts)); save('active_dataset_sizes.json',sizes)  # Record actual server storage.
        measured=measure('task3','baseline',size,n)  # Time the full six queries at every size.
        if size==5: baseline=measured  # Retain the exact largest-data baseline.
        print(f'Task 3 S{size} completed: {n} sales.',flush=True)  # Provide progress without exposing connection secrets.
    for spec in specs['candidates']:  # Evaluate seven independent candidate configurations.
        drop_optional(); cost=build(spec['statements']); measured=measure('task4_candidate',spec['id'],5,n,True)  # Restore baseline, build, validate and time.
        used={node.get('Index Name') for p in measured['plans'] for node in p['nodes']}  # Read real planner choices rather than assuming index usage.
        ratio=math.exp(statistics.mean(math.log(m/b) for m,b in zip(measured['means'],baseline['means'])))  # Weight queries equally when choosing a bundle.
        candidates.append(dict(id=spec['id'],reason=spec['reason'],statements=spec['statements'],means=measured['means'],used_indexes=[i['indexname'] for i in measured['indexes'] if i['indexname'].startswith('t4_') and i['indexname'] in used],geometric_ratio=ratio,**cost))  # Keep negative results in the record.
        save('candidate_results.json',candidates)  # Preserve exploration separately from confirmation.
    selected=[c for c in candidates if c['geometric_ratio']<0.98 and c['used_indexes']]  # Apply the same declared selection rule on the native server.
    statements=[s for c in selected for s in c['statements']]  # Combine selected candidates without assuming additive gains.
    drop_optional(); cost=build(statements); final=measure('task4_confirmation','selected_final',5,n,True)  # Run five new confirmation repeats.
    save('final_selection.json',dict(selected_candidate_ids=[c['id'] for c in selected],statements=statements,selection_rule=specs['final_selection_rule'],baseline_means=baseline['means'],indexed_means=final['means'],**cost))  # Let actual native results determine native recommendations.
    (out/'selected_indexes.sql').write_text(f'SET search_path = {schema}, public; -- Use the freshly measured schema.\n'+'\n'.join(statements)+'\n')  # Export the native-selected DDL.
    groups={}  # Collect homogeneous five-repeat groups.
    for r in raw: groups.setdefault((r['phase'],r['configuration'],r['size_level'],r['query_no']),[]).append(r)  # Never mix sizes or configurations.
    summary=[]  # Derive transparent mean and sample-standard-deviation tables.
    for (phase,config,size,q),g in groups.items():  # Summarize every required group exactly once.
        if len(g)!=5: raise ValueError('Incomplete timing group')  # Fail before reporting partial measurements as complete.
        times=[r['execution_ms'] for r in g]; summary.append(dict(phase=phase,configuration=config,size_level=size,transaction_rows=g[0]['transaction_rows'],query_no=q,mean_ms=statistics.mean(times),sd_ms=statistics.stdev(times),min_ms=min(times),max_ms=max(times)))  # Use sample SD with denominator n−1.
    csv_export('benchmark_summary.csv',summary,list(summary[0])); save('result_row_counts.json',row_counts)  # Export final derived and correctness evidence.
    save('database_checks.json',query('SELECT count(*)::integer AS transactions,min(sale_month)::text AS earliest,max(sale_month)::text AS latest,count(DISTINCT sale_month)::integer AS months,(SELECT count(*) FROM nearby)::integer AS stored_links,(SELECT count(*) FROM nearby_classified)::integer AS classified_links FROM resale_transaction')[0])  # Recheck the complete fixed scope.
    save('experiment_complete.json',dict(complete=True,total_observations=len(raw),native_server=True,schema=schema))  # Claim completion only after all experiments finish.
    print(f'Complete. Evidence: {out}; schema retained: {schema}',flush=True)  # Retain the real database for pgAdmin inspection.
