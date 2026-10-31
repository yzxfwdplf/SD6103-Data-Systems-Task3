import {PGlite} from '@electric-sql/pglite'; // Execute actual PostgreSQL in the declared WASM runtime.
import fs from 'node:fs'; // Preserve source data, plans and every timing record.
import path from 'node:path'; // Resolve paths independently of the shell working directory.
import os from 'node:os'; // Record the execution host without claiming it is a native server.
import crypto from 'node:crypto'; // Fingerprint SQL, data and complete result sets.
import {performance} from 'node:perf_hooks'; // Record index creation wall time separately from SELECT time.
import {fileURLToPath} from 'node:url'; // Locate this script in the delivered package.
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'); // Use a portable project root.
const data=path.join(root,'data/processed'),out=path.resolve(process.argv[2]||path.join(root,'evidence/run')); // Keep new evidence separate.
if(fs.existsSync(out)&&fs.readdirSync(out).length)throw Error('Choose a new empty output directory.'); // Protect earlier observations.
for(const p of ['','results','plans','sql_used','configurations'])fs.mkdirSync(path.join(out,p),{recursive:true}); // Create evidence folders.
const save=(n,v)=>fs.writeFileSync(path.join(out,n),JSON.stringify(v,null,2)); // Persist structured evidence immediately.
const sha=s=>crypto.createHash('sha256').update(s).digest('hex'); // Use exact SHA-256 fingerprints.
const tables=['town','hdb_flat','resale_transaction','hawker_centre','proximity_level','nearby']; // Include all six merged base relations.
const manifest=JSON.parse(fs.readFileSync(path.join(data,'data_manifest.json'),'utf8')); // Check declared load sizes.
const specs=JSON.parse(fs.readFileSync(path.join(root,'sql/05_index_candidates.json'),'utf8')); // Use one portable candidate specification.
const queries=Object.fromEntries(Array.from({length:6},(_,i)=>[i+1,fs.readFileSync(path.join(root,`sql/queries/Q${i+1}.sql`),'utf8')])); // Share the report's exact query files.
for(const [q,s] of Object.entries(queries))fs.writeFileSync(path.join(out,`sql_used/Q${q}.sql`),s); // Freeze the measured SQL once.
const raw=[],sizes=[],configs=[],baseFingerprints={},rowCounts={}; // Keep measured and validation evidence together.
const fields=['phase','configuration','size_level','transaction_rows','active_table_bytes','query_no','repetition','execution_ms','planning_ms','result_rows','sql_sha256']; // Define one raw-record schema.
fs.writeFileSync(path.join(out,'measurements_raw.csv'),fields.join(',')+'\n'); // Start an append-only observation file.
const exportCSV=(n,rows,cols)=>fs.writeFileSync(path.join(out,n),cols.join(',')+'\n'+rows.map(r=>cols.map(c=>r[c]===null||r[c]===undefined?'':JSON.stringify(String(r[c]))).join(',')).join('\n')+'\n'); // Quote CSV cell values faithfully.
const fingerprint=rows=>sha(JSON.stringify(rows.map(r=>Object.keys(r).sort().map(k=>[k,r[k]===null?null:String(r[k])])).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b))))); // Compare group values independently of presentation order.
const db=await PGlite.create(); // Start a new isolated database with no inherited optional indexes.
async function copy(table,file){ // Bulk-load only audited generated CSVs.
 const buf=fs.readFileSync(path.join(data,file)),cols=buf.toString('utf8',0,buf.indexOf(10)).trim().split(','); // Preserve explicit CSV column order.
 if(!cols.every(c=>/^[a-z_]+$/.test(c)))throw Error('Invalid CSV header'); // Reject unexpected SQL identifiers.
 await db.exec(`COPY housing.${table} (${cols.join(',')}) FROM '/dev/blob' WITH (FORMAT CSV,HEADER TRUE)`,{blob:new Blob([buf])}); // Use actual PostgreSQL COPY.
}
async function footprints(){ // Measure current six-table relation storage.
 const result=[]; // Retain each table's own size.
 for(const table of tables)result.push({table,...(await db.query(`SELECT count(*)::integer AS rows,pg_total_relation_size('housing.${table}')::bigint AS bytes FROM housing.${table}`)).rows[0]}); // Include constraint and optional indexes.
 return result; // Keep component counts auditable.
}
async function indexInventory(){ // Record exactly which indexes exist in each experiment.
 return (await db.query("SELECT tablename,indexname,indexdef,pg_relation_size((schemaname||'.'||indexname)::regclass)::bigint AS bytes FROM pg_indexes WHERE schemaname='housing' ORDER BY tablename,indexname")).rows; // Distinguish constraints from optional t4 indexes.
}
function nodes(plan,out=[]){ // Extract plan details used in the final discussion.
 out.push(Object.fromEntries(['Node Type','Relation Name','Index Name','Actual Rows','Actual Loops','Heap Fetches','Sort Method','Sort Space Used','Sort Space Type','Rows Removed by Filter','Shared Hit Blocks','Shared Read Blocks','Temp Read Blocks','Temp Written Blocks'].filter(k=>k in plan).map(k=>[k,plan[k]]))); // Preserve actual operators and usage evidence.
 for(const child of plan.Plans||[])nodes(child,out); // Visit nested query operators.
 return out; // Return a compact but traceable plan summary.
}
async function measure(phase,configuration,size,n,checkResults=false){ // Run the same exact six SELECT statements for each configuration.
 const tableSizes=await footprints(),bytes=tableSizes.reduce((a,t)=>a+Number(t.bytes),0); // Measure size outside query timing.
 const inventory=await indexInventory();save(`configurations/${configuration}_S${size}_indexes.json`,inventory); // Prove the baseline is uncontaminated.
 rowCounts[`${configuration}_S${size}`]={}; // Track result-row counts for all sizes.
 for(let q=1;q<=6;q++){ // Export and optionally compare the complete output before timing.
  const result=await db.query(queries[q]);rowCounts[`${configuration}_S${size}`][q]=result.rows.length; // Execute all required projections and calculations.
  const digest=fingerprint(result.rows); // Fingerprint exact grouped results.
  if(checkResults&&digest!==baseFingerprints[q])throw Error(`Result changed for ${configuration} Q${q}`); // Reject an index experiment that changes semantics.
  if(configuration==='baseline'&&size===5)baseFingerprints[q]=digest; // Preserve the final-data baseline result.
  save(`results/${configuration}_S${size}_Q${q}.json`,result); // Keep every complete result as evidence.
  exportCSV(`results/${configuration}_S${size}_Q${q}.csv`,result.rows,result.fields.map(f=>f.name)); // Supply readable complete results.
 }
 for(let q=1;q<=6;q++)await db.query('EXPLAIN (ANALYZE,BUFFERS,TIMING OFF,FORMAT JSON) '+queries[q]); // Exclude one full-query warm-up per query/configuration.
 const planSummaries=[]; // Keep a representative plan for each query.
 for(let rep=1;rep<=5;rep++){ // Record the five required repeats.
  for(const q of Array.from({length:6},(_,k)=>(k+size+rep)%6+1)){ // Rotate the first query across repetitions.
   const plan=(await db.query('EXPLAIN (ANALYZE,BUFFERS,TIMING OFF,FORMAT JSON) '+queries[q])).rows[0]['QUERY PLAN'][0]; // Measure the full SELECT without COUNT wrappers.
   save(`plans/${configuration}_S${size}_Q${q}_R${rep}.json`,plan); // Preserve every actually timed execution plan.
   if(rep===1)planSummaries.push({query_no:q,execution_ms:plan['Execution Time'],nodes:nodes(plan.Plan)}); // Summarize the first measured plan.
   const row={phase,configuration,size_level:size,transaction_rows:n,active_table_bytes:bytes,query_no:q,repetition:rep,execution_ms:plan['Execution Time'],planning_ms:plan['Planning Time'],result_rows:plan.Plan['Actual Rows'],sql_sha256:sha(queries[q])}; // Keep planning separate from executor time.
   raw.push(row);fs.appendFileSync(path.join(out,'measurements_raw.csv'),fields.map(k=>row[k]).join(',')+'\n'); // Flush each raw observation immediately.
  }
 }
 save(`configurations/${configuration}_S${size}_plans.json`,planSummaries); // Link interpreted plans to the complete originals.
 const means=Array.from({length:6},(_,i)=>raw.filter(r=>r.configuration===configuration&&r.size_level===size&&r.query_no===i+1).reduce((a,r)=>a+r.execution_ms,0)/5); // Summarize this measured group only.
 return {means,index_inventory:inventory,plan_summaries:planSummaries,active_table_bytes:bytes,result_fingerprints:checkResults?'all six match baseline':Object.fromEntries(Object.entries(baseFingerprints))}; // Preserve correctness and physical configuration evidence.
}
async function createIndexes(spec){ // Build one explicit candidate or the final selected bundle.
 const statements=spec.statements,started=performance.now(); // Record build overhead separately.
 for(const sql of statements)await db.exec(sql); // Create only the named optional indexes.
 const inventory=await indexInventory(); // Measure their resulting storage.
 return {build_wall_ms:performance.now()-started,extra_index_bytes:inventory.filter(i=>i.indexname.startsWith('t4_')).reduce((a,i)=>a+Number(i.bytes),0)}; // Report cost as well as query benefit.
}
async function dropAnalytical(){ // Return to the same constraint-only baseline between candidates.
 const names=(await indexInventory()).filter(i=>i.indexname.startsWith('t4_')).map(i=>i.indexname); // Only consider indexes created by this isolated experiment.
 for(const name of names)await db.exec(`DROP INDEX housing.${name}`); // Preserve primary, unique and exclusion-constraint indexes.
}
try{ // Always close the database even if validation fails.
 await db.exec(fs.readFileSync(path.join(root,'sql/01_schema.sql'),'utf8')); // Load the merged schema without running the teammate's destructive reset.
 for(const t of tables.filter(t=>t!=='resale_transaction'))await copy(t,`${t}.csv`); // Keep the five reference relations fixed.
 for(const t of tables.filter(t=>t!=='resale_transaction'))await db.exec(`VACUUM (ANALYZE) housing.${t}`); // Give all configurations the same read-mostly visibility state.
 const environment={version:(await db.query('SELECT version() AS v')).rows[0].v,runtime:'PostgreSQL/WASM through PGlite 0.5.10',node:process.version,cpu:os.cpus()[0]?.model,logical_cpus:os.cpus().length,os:os.platform()+' '+os.release(),captured_utc:new Date().toISOString(),metric:'EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, FORMAT JSON) Execution Time',storage:'In-memory virtual filesystem; not native disk I/O',maintenance:'VACUUM (ANALYZE) before every Task 3 stage; no data changes during Task 4; planner defaults retained'}; // Record actual provenance.
 environment.settings=(await db.query("SELECT name,setting,unit FROM pg_settings WHERE name IN ('work_mem','shared_buffers','max_parallel_workers_per_gather','jit','enable_seqscan','enable_indexscan','enable_indexonlyscan') ORDER BY name")).rows; // Prove optional planner paths were not forced.
 environment.sql_sha256=Object.fromEntries(Object.entries(queries).map(([q,s])=>[q,sha(s)]));save('environment.json',environment); // Freeze query fingerprints before timing.
 let baseline; // Keep the exact S5 Task 3 comparison baseline.
 for(let s=1;s<=5;s++){ // Measure the agreed fixed-period cumulative data sizes.
  await copy('resale_transaction',`transactions_part${s}.csv`); // Add each disjoint partition once.
  await db.exec('VACUUM (ANALYZE) housing.resale_transaction'); // Apply maintenance equally before every baseline size.
  const counts=await footprints(),n=counts.find(t=>t.table==='resale_transaction').rows; // Read actual loaded row counts.
  if(n!==manifest.stages[s-1].transaction_rows)throw Error(`Unexpected S${s} count ${n}`); // Stop before timing an incomplete or duplicated load.
  if((await indexInventory()).some(i=>i.indexname.startsWith('t4_')))throw Error('Contaminated Task 3 baseline'); // Reject prematurely created analytical indexes.
  sizes.push({size_level:s,transaction_rows:n,tables:counts});save('active_dataset_sizes.json',sizes); // Persist true database footprints.
  const result=await measure('task3','baseline',s,n);if(s===5)baseline=result; // Measure each complete SELECT five times.
  console.log(`Task 3 S${s}: ${n} rows; thirty measured executions.`); // Report progress on real work.
 }
 const n=manifest.matched_transactions; // Use the same maximum scoped population for all index comparisons.
 for(const spec of specs.candidates){ // Evaluate candidates independently before choosing a combined set.
  await dropAnalytical();const cost=await createIndexes(spec); // Avoid interaction with previous candidate indexes.
  const measured=await measure('task4_candidate',spec.id,5,n,true); // Require unchanged complete output and five measured repeats.
  const used=new Set(measured.plan_summaries.flatMap(p=>p.nodes.map(n=>n['Index Name']).filter(Boolean))); // Read actual planner index choices.
  const owned=measured.index_inventory.filter(i=>i.indexname.startsWith('t4_')).map(i=>i.indexname); // Identify this candidate's created indexes.
  const geometric_ratio=Math.exp(measured.means.reduce((a,m,i)=>a+Math.log(m/baseline.means[i]),0)/6); // Weight all six queries equally.
  const result={id:spec.id,reason:spec.reason,statements:spec.statements,...cost,means:measured.means,used_indexes:owned.filter(i=>used.has(i)),geometric_ratio}; // Preserve trial outcome, including failures to improve.
  configs.push(result);save('candidate_results.json',configs);console.log(`Candidate ${spec.id}: ratio ${geometric_ratio.toFixed(3)}; used ${result.used_indexes.join(',')||'none'}`); // Report actual usage and timing.
 }
 const selected=configs.filter(c=>c.geometric_ratio<0.98&&c.used_indexes.length); // Follow the declared exploratory selection rule.
 const finalSpec={id:'selected_final',statements:selected.flatMap(c=>c.statements)}; // Test interactions in a fresh combined configuration.
 await dropAnalytical();const cost=await createIndexes(finalSpec); // Recreate the selected set without leftover candidates.
 const final=await measure('task4_confirmation','selected_final',5,n,true); // Hold out five new repeats for the chosen bundle.
 const finalResult={selected_candidate_ids:selected.map(c=>c.id),statements:finalSpec.statements,selection_rule:specs.final_selection_rule,...cost,baseline_means:baseline.means,indexed_means:final.means,used_indexes:[...new Set(final.plan_summaries.flatMap(p=>p.nodes.map(n=>n['Index Name']).filter(Boolean)))],result_fingerprints:'All six complete outputs equal the S5 baseline'}; // Report confirmed effects without adding individual benefits together.
 save('final_selection.json',finalResult);fs.writeFileSync(path.join(out,'selected_indexes.sql'),'SET search_path = housing, public; -- Use the measured schema.\n\n'+finalSpec.statements.join('\n\n')+'\n'); // Export exactly the confirmed index DDL.
 const groups=new Map();for(const r of raw){const key=[r.phase,r.configuration,r.size_level,r.query_no].join('|');if(!groups.has(key))groups.set(key,[]);groups.get(key).push(r);} // Group all raw observations once.
 const summaries=[...groups.values()].map(g=>{if(g.length!==5)throw Error('Incomplete group');const mean=g.reduce((a,r)=>a+r.execution_ms,0)/5;return {phase:g[0].phase,configuration:g[0].configuration,size_level:g[0].size_level,transaction_rows:g[0].transaction_rows,query_no:g[0].query_no,mean_ms:mean,sd_ms:Math.sqrt(g.reduce((a,r)=>a+(r.execution_ms-mean)**2,0)/4),min_ms:Math.min(...g.map(r=>r.execution_ms)),max_ms:Math.max(...g.map(r=>r.execution_ms))};}); // Use sample SD for all five-repeat groups.
 exportCSV('benchmark_summary.csv',summaries,Object.keys(summaries[0]));save('result_row_counts.json',rowCounts); // Supply complete raw and derived tables.
 save('database_checks.json',(await db.query("SELECT count(*)::integer AS transactions,min(sale_month)::text AS earliest,max(sale_month)::text AS latest,count(DISTINCT sale_month)::integer AS months,(SELECT count(*) FROM nearby)::integer AS stored_links,(SELECT count(*) FROM nearby_classified)::integer AS classified_links FROM resale_transaction")).rows[0]); // Verify scope again after every experiment.
 save('experiment_complete.json',{complete:true,task3_observations:raw.filter(r=>r.phase==='task3').length,candidate_observations:raw.filter(r=>r.phase==='task4_candidate').length,confirmation_observations:raw.filter(r=>r.phase==='task4_confirmation').length,total_observations:raw.length,finished_utc:new Date().toISOString(),native_server:false}); // Declare completion only after all evidence is saved.
 console.log('Complete: merged Task 3 and independently tested Task 4 index evidence.'); // Confirm actual completion.
}finally{await db.close();} // Release the isolated PostgreSQL backend.
