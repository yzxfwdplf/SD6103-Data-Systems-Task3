from pathlib import Path  # Resolve portable output and evidence paths.
import csv, json, math, statistics  # Recompute all report numbers from raw observations.
import matplotlib  # Use a deterministic noninteractive figure renderer.
matplotlib.use('Agg')  # Render figures without a desktop session.
import matplotlib.pyplot as plt  # Draw actual-result excerpts and measured-runtime charts.
ROOT=Path(__file__).resolve().parents[1]  # Locate the delivered package.
RUN=ROOT/'evidence/run'; FIG=ROOT/'evidence/figures'; REPORT=ROOT/'report'  # Keep evidence and report sources together.
FIG.mkdir(parents=True,exist_ok=True); REPORT.mkdir(exist_ok=True)  # Create only the requested artifact directories.
rows=list(csv.DictReader((RUN/'measurements_raw.csv').open()))  # Read the 390 actual observations without resampling.
summary=list(csv.DictReader((RUN/'benchmark_summary.csv').open()))  # Read the independently checked summary table.
candidates=json.loads((RUN/'candidate_results.json').read_text()); final=json.loads((RUN/'final_selection.json').read_text())  # Keep exploration separate from confirmation.
sizes=json.loads((RUN/'active_dataset_sizes.json').read_text())  # Use measured six-table footprints.
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False})  # Use consistent, legible figures.
def group(config,q,size=5):  # Select a homogeneous five-repeat measurement group.
 return [float(r['execution_ms']) for r in rows if r['configuration']==config and int(r['query_no'])==q and int(r['size_level'])==size]  # Never mix sizes or configurations.
def stats(config,q,size=5):  # Compute mean and sample deviation directly from raw values.
 a=group(config,q,size); assert len(a)==5; return statistics.mean(a),statistics.stdev(a)  # Require complete five-repeat evidence.
def tex(s):  # Escape source names for safe LaTeX table rendering.
 return str(s).replace('\\',r'\textbackslash{}').replace('_',r'\_').replace('%',r'\%').replace('&',r'\&')  # Preserve literal labels.
def table(header,body,caption,align=None):  # Apply the reference's centered booktabs layout and lower caption.
 return '\n\\begin{table}[H]\\centering\\small\n\\begin{tabular}{'+(align or 'l'+'r'*(len(header)-1))+'}\n\\toprule\n'+' & '.join(header)+r' \\'+'\n\\midrule\n'+'\n'.join(' & '.join(map(str,r))+r' \\' for r in body)+'\n\\bottomrule\n\\end{tabular}\n\\caption{'+caption+'}\n\\end{table}\n'  # Keep labels and units next to every result.
def figure(name,caption,width='0.95'):  # Keep figure captions below their graphics.
 return '\n\\begin{figure}[H]\\centering\n\\includegraphics[width='+width+'\\linewidth]{../evidence/figures/'+name+'}\n\\caption{'+caption+'}\\end{figure}\n'  # Refer only to generated evidence.
for q in range(1,7):  # Render result excerpts from the newly executed SQL exports.
 result=json.loads((RUN/f'results/baseline_S5_Q{q}.json').read_text())['rows']  # Read exact complete results.
 selected=result[:10] if q!=6 else [r for r in result if r['town_name']=='BUKIT BATOK' and r['fresh_market_status']=='unknown']  # Match the report's displayed population.
 cols=list(selected[0]); cells=[[str(r[k]) for k in cols] for r in selected]  # Preserve SQL column and value order.
 labels=[k.replace('_','\n') for k in cols]  # Wrap long headings without changing their meaning.
 fig,ax=plt.subplots(figsize=(13.1,1.4+len(cells)*.42)); ax.axis('off')  # Crop around the actual table content.
 ax.set_title(f'Q{q} | Actual merged-query output | Jan 2023–Dec 2025\nPostgreSQL 18.6 / PGlite 0.5.10 · {len(result)} full-result rows',loc='left',fontsize=13,pad=20)  # Identify scope and actual execution environment.
 t=ax.table(cellText=cells,colLabels=labels,loc='center',cellLoc='left',bbox=[0,0,1,.88]); t.auto_set_font_size(False); t.set_fontsize(9.5)  # Use consistent readable output excerpts.
 for (r,c),cell in t.get_celld().items():  # Style the evidence viewer rather than imitating pgAdmin.
  cell.set_edgecolor('#d5dce3'); cell.set_linewidth(.5)  # Separate values with unobtrusive rules.
  if r==0: cell.set_facecolor('#e7edf3'); cell.set_text_props(weight='bold'); cell.set_height(.16)  # Distinguish headings.
  elif r%2==0: cell.set_facecolor('#f6f8fa')  # Track rows across wide tables.
 fig.savefig(FIG/f'Q{q}_result.png',dpi=180,bbox_inches='tight'); plt.close(fig)  # Export an actual-result viewer, not a database-UI screenshot.
means=[[stats(c,q)[0] for q in range(1,7)] for c in ['baseline','selected_final']]  # Read the exact largest-data comparison.
sds=[[stats(c,q)[1] for q in range(1,7)] for c in ['baseline','selected_final']]  # Show variability instead of a single best run.
fig,axes=plt.subplots(2,3,figsize=(11.8,6.7))  # Give each query its own readable scale.
for q,ax in enumerate(axes.flat,1):  # Compare both configurations for every required query.
 vals=[m[q-1] for m in means]; errors=[s[q-1] for s in sds]  # Use all five repeats and sample SD.
 bars=ax.bar(['Task 3 baseline','Confirmed indexes'],vals,yerr=errors,capsize=4,color=['#336b9b','#43896b'],width=.6)  # Use honest zero-baseline columns.
 ax.set_ylim(0,max(v+e for v,e in zip(vals,errors))*1.28); ax.set_ylabel('Execution time (ms)'); ax.set_title(f'Q{q}')  # Label units and per-query panels.
 for b,v in zip(bars,vals): ax.text(b.get_x()+b.get_width()/2,b.get_height()+max(vals)*.045,f'{v:.2f}',ha='center',fontsize=9)  # Preserve exact readable means.
fig.suptitle('Largest scoped dataset: 78,670 sales · 5 repeats per query/configuration',fontsize=13); fig.tight_layout(rect=[0,0,1,.95])  # Avoid hiding smaller-query effects behind Q6.
fig.savefig(FIG/'Task4_comparison.png',dpi=190,bbox_inches='tight'); plt.close(fig)  # Save report-ready measured comparison.
fig,ax=plt.subplots(figsize=(10.4,4.8))  # Show the fresh Task 3 scalability baseline.
for q in range(1,7): ax.plot([s['transaction_rows'] for s in sizes],[stats('baseline',q,s)[0] for s in range(1,6)],marker='o',label=f'Q{q}')  # Use all five actual cumulative sizes.
ax.set_xlabel('Transactions within Jan 2023–Dec 2025'); ax.set_ylabel('Mean execution time (ms)'); ax.set_ylim(bottom=0); ax.legend(ncol=6); ax.grid(axis='y',alpha=.2)  # Keep population and runtime units explicit.
fig.tight_layout(); fig.savefig(FIG/'Task3_scaling.png',dpi=180); plt.close(fig)  # Preserve the merged-code baseline rather than teammate historical timings.
base=means[0]; indexed=means[1]; ratios=[b/a for a,b in zip(base,indexed)]  # Define ratios consistently as indexed divided by baseline.
geo=math.exp(statistics.mean(math.log(x) for x in ratios)); reduction=(sum(base)-sum(indexed))/sum(base)*100  # Distinguish equal-query and total-time summaries.
head=(ROOT/'provenance/report_style_template.txt').read_text()  # Reuse the user's established academic layout.
prefix=head.split(r'\Needspace{10\baselineskip}\subsection{Performance measurements}')[0]  # Retain checked Q1–Q6 explanations and tables.
prefix=prefix.replace('The five base relations follow the final ER naming:', 'The six logical base relations preserve the final ER entities and add one distance-band lookup:').replace(r'and \texttt{nearby}.',r'\texttt{nearby}, and \texttt{proximity\_level}.')  # Describe the merged logical mapping accurately.
prefix=prefix.replace('The view is not a sixth base relation.','The view reads the three-row proximity lookup; the lookup is a logical implementation detail rather than a new conceptual ER entity. Its non-overlap constraint prevents one stored link matching two bands.')  # Explain why the chosen ER remains recognizable.
prefix=prefix.replace('All five base relations participate; nearby is read through its classified view.','All six base relations participate explicitly, including the proximity lookup. Nearby, hawker and proximity memberships are deduplicated before joining town, address and transaction rows.')  # Match the final Q6 six-table SQL.
prefix=prefix.replace('DISTINCT ON selects each address\'s nearest stored hawker, breaking distance ties by hawker ID.',"DISTINCT ON selects each address's nearest stored hawker, breaking distance ties by hawker ID. Nearest selection runs on the raw nearby relation before the band lookup, exposing its ordering to a potential composite index.")  # Explain the Q4 structural optimization.
prefix=prefix.replace('offline viewer','generated result-table viewer').replace('../sql/Q','../sql/queries/Q')  # Point to the single measured SQL source.
prefix=prefix.replace('pdfauthor={Transcend Self}','pdfauthor={SD6103 Project Group}').replace('SD6103 Task 3: January 2023 - December 2025','SD6103 Merged Tasks 3 and 4: 2023-2025')  # Remove the earlier personal attribution.
prefix=prefix.replace(r'\usepackage[hidelinks]{hyperref}',r'\usepackage[hidelinks]{hyperref}'+ '\n'+r'\usepackage{xurl}')  # Allow long source URLs to wrap within the reference margins.
preamble=prefix.split(r'\begin{document}')[0]  # Share typography across the combined and standalone reports.
perf=r'''
\Needspace{10\baselineskip}\subsection{Merged-code performance measurements}
All five increasing sizes use the same 2023--2025 period. A stable source-row hash assigns each sale to one of five disjoint partitions: the first sixteen hexadecimal digits, interpreted as an integer, modulo five, plus one. The next partition is added at each size. All 36 months occur at every size; S5 contains every scoped transaction exactly once. Five reference relations remain fixed, including the three-row proximity lookup.

\textbf{Protocol scope.} The project guide's original five historical source-file increments differ from these within-period partitions. All selected 2023--2025 sales originate in the latest historical file. Approval of this revised protocol, or an additional experiment with the original five-file procedure, is required before claiming full compliance with that requirement.
'''
perf+=table(['Size','Transactions','Months','Six-table MiB'],[[f'S{i+1}',f"{s['transaction_rows']:,}",'36',f"{sum(t['bytes'] for t in s['tables'])/2**20:.2f}"] for i,s in enumerate(sizes)],'Measured database footprints, including constraint indexes and TOAST, before analytical indexes.')  # Report actual merged-schema storage.
perf+=r'''
Each reference relation is bulk-loaded once. VACUUM (ANALYZE) precedes every transaction-size baseline; data and maintenance state remain fixed throughout Task 4. Primary-key, unique and exclusion indexes are retained. No optional analytical index exists in Task 3. Each complete SELECT is exported, warmed up once, and executed five measured times. Query order rotates cyclically. The metric is PostgreSQL Execution Time from EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, FORMAT JSON); planning is recorded separately. Loading, output transfer and rendering are outside timing. No COUNT wrapper replaces the required SELECT.
'''
perf+=table(['Size']+[f'Q{q}' for q in range(1,7)],[[f'S{s}']+[f'{stats("baseline",q,s)[0]:.2f}' for q in range(1,7)] for s in range(1,6)],'Mean executor milliseconds for the 150 fresh merged-code Task 3 observations.','lrrrrrr')  # Derive every cell from raw timings.
perf+=figure('Task3_scaling.png','Fresh baseline means across five fixed-period cumulative populations.')  # Preserve comparability with Task 4.
perf+=r'''
\textbf{Insight.} Q6 is the largest cost in this execution environment because its valid address/band/status memberships still expand into many sale memberships before grouping. Deduplicating membership before the transaction join protects correctness and reduces intermediate multiplication, but does not make the remaining aggregate selective. Sequential scans are reasonable for queries consuming most of the scoped population. These are measured scaling observations, not native disk-I/O or cross-machine claims.

\subsection{Integration and correctness checks}
The integration uses the teammate's six-relation lookup design and bulk-load approach, together with the scoped package's row keys, date constraints, nullable fresh-market status, fixed Q5 budget and independent validation. The uploaded SQL contributes the transaction-deduplication principle; the final Q5/Q6 form applies equivalent deduplication at the smaller address-membership grain. Q4 keeps deterministic nearest-centre selection. A single query-file set supplies displayed SQL, exported results and every benchmark configuration.

Independent pandas recomputation passes all six largest-data outputs: 52, 62, 30, 73, 11 and 154 groups. Every optional-index configuration produces the exact same complete output fingerprint as the S5 baseline. The common scope is 78,670 transactions and 36 months, with 40,354 stored and classified nearby links. The prior historical native timings and the uploaded 1997--1999 Q1 window are not reused as results for this instance.
'''
task4=r'''
\section{Task 4: Index Design and Experimental Evaluation}
\subsection{Objective and controlled protocol}
Task 4 selects indexes from actual EXPLAIN plans, runs each query five times on the largest Task 3 dataset, and compares indexed execution with that exact baseline. The deliverables include commented index DDL, raw observations, an Excel column chart, interpreted execution plans and reproducible scripts. This experiment uses 78,670 sales from January 2023 through December 2025; it does not mix the teammate's all-history population into the comparison.

The completed run contains 390 measured executions: 150 Task 3 baseline observations, 210 isolated candidate observations (seven configurations, six queries, five repeats), and 30 fresh confirmation observations. Each configuration has an excluded full-query warm-up and an untimed complete-result equality check. Data, SQL fingerprints, planner defaults and visibility maintenance remain unchanged. No index is forced by disabling sequential scans.

\textbf{Environment.} PostgreSQL 18.6 through PGlite 0.5.10, Node 24.22.1, Linux, Intel Xeon Platinum 8573C; nine logical CPUs are visible, while PostgreSQL parallel workers per gather are zero. Shared buffers are 128 MiB and work\_mem is 4 MiB. Storage is an in-memory WASM virtual filesystem. These actual timings are not a native PostgreSQL or physical-disk benchmark. The supplied native runner records the real server version and settings and repeats the full experiment in a new isolated schema.

\subsection{Plan-driven candidate design}
The baseline scans most transactions for Q1/Q2/Q4--Q6. Q3 filters the 3 ROOM subset twice. Q4 needs nearby rows ordered by address, distance and hawker ID. Q5/Q6 use address-centre memberships, and Q6 has a substantial grouping/sort workload. These observed operators motivate the following independent candidates.
'''
labels={'team_generic':'Date/type + address + lease','nearest_order':'Nearest-centre ordering','partial_3room':'3 ROOM partial covering','partial_45room':'4/5 ROOM partial covering','sale_cover':'Transaction address covering','hawker_links':'Reverse hawker membership','town_addresses':'Town/address ordering'}  # Provide readable candidate labels.
body=[]  # Build the full candidate outcome table without dropping negative results.
for c in candidates: body.append([labels[c['id']],f"{c['geometric_ratio']:.3f}",f"{c['extra_index_bytes']/2**20:.3f}",'yes' if c['used_indexes'] else 'no'])  # Report actual planner usage and storage.
task4+=table(['Isolated candidate','Geo. ratio','Index MiB','Used'],body,'Exploratory ratio is the geometric mean of indexed/baseline mean times across Q1--Q6; below 1 is faster.','lrrl')  # Explain ratio direction next to the table.
task4+=r'''
The seven candidate DDL definitions are provided in \texttt{sql/05\_index\_candidates.json}; each statement has an explanatory trailing comment. Covering candidates include only projected/filter columns needed by their target queries. The 3 ROOM and 4/5 ROOM partial predicates match the corresponding query predicates. The nearest-order candidate matches Q4's deterministic ordering. The hawker-led and town-led alternatives test whether their join orders are useful rather than assuming that every foreign key needs an index for this analytical workload.

Index-only scans require both suitable index columns and visibility information. Equal VACUUM maintenance is therefore applied before baseline/index comparisons. The partial 3 ROOM trial actually uses two index-only scans with zero heap fetches, while the nearest-order trial eliminates Q4's incremental sort through an index-only scan. These plan improvements did not guarantee lower total six-query runtime in this environment. The reverse hawker index was not used. The town/address index was used but did not pass the aggregate selection criterion.

\subsection{Selection rule and confirmed index bundle}
The rule recorded before candidate evaluation retains a candidate group only when an actual plan uses one of its indexes and the equal-query-weight geometric mean ratio is below 0.98. Retained groups are recreated together and tested with five new repeats; individual gains are never added together. Only the teammate's three-index group passed the exploratory rule in this run. The fresh confirmation therefore measures precisely the following DDL.
'''
task4+=r'\lstinputlisting{../evidence/run/selected_indexes.sql}'+'\n'  # Display the exact measured index bundle.
task4+=r'''
This is the confirmed experimental bundle, not a claim that three indexes are universally optimal. Within it, only \texttt{t4\_team\_month\_type} appears in the six-query plans. The address and lease indexes add storage/build/write cost without observed read benefit here. A practical deployment should test a pruned date/type-only bundle on native PostgreSQL before retaining those two unused indexes; its performance is not fabricated in this report. The selection rule evaluates candidate groups, so the measured three-index confirmation is preserved rather than silently relabelled as a one-index result.
'''
body=[]  # Compare all six queries using fresh confirmation values.
for q in range(1,7):
 a,sa=stats('baseline',q); b,sb=stats('selected_final',q); body.append([f'Q{q}',f'{a:.2f}',f'{sa:.2f}',f'{b:.2f}',f'{sb:.2f}',f'{(a-b)/a*100:+.2f}'])  # A negative reduction denotes slower indexed execution.
task4+=table(['Query','Base mean','Base SD','Index mean','Index SD',r'Reduction \%'],body,'Largest-data executor times in milliseconds; five repeats and sample SD per query/configuration. Positive reduction means faster.','lrrrrr')  # Keep dispersion alongside means.
task4+=figure('Task4_comparison.png','Task 3 S5 baseline versus the fresh confirmed bundle. Bars show means; error bars show sample SD. Every panel begins at zero.')  # Supply the requested bar-chart comparison.
task4+=f'\\textbf{{Insight.}} Q3 falls from {base[2]:.2f} ms to {indexed[2]:.2f} ms, a {(base[2]-indexed[2])/base[2]*100:.2f}\\% reduction. Q1, Q2, Q4 and Q6 are slower in the confirmation, while Q5 is slightly faster. The confirmation geometric mean ratio is {geo:.3f}; the sum of six mean times changes from {sum(base):.2f} to {sum(indexed):.2f} ms ({reduction:+.2f}\\% reduction). The equal-query ratio suggests a modest improvement, while the sum of query means regresses; these two weightings must not be confused. This does not establish a uniformly faster workload. Five warm repeats on one host do not establish statistical significance.\n'  # State mixed and negative results without selecting the best repetition.
task4+=table(['Query']+[f'Base R{r}' for r in range(1,6)],[[f'Q{q}']+[f'{x:.3f}' for x in group('baseline',q)] for q in range(1,7)],'All five raw largest-data baseline times (ms); repetition identity follows the raw CSV.','lrrrrr')  # Make the reported baseline auditable.
task4+=table(['Query']+[f'Index R{r}' for r in range(1,6)],[[f'Q{q}']+[f'{x:.3f}' for x in group('selected_final',q)] for q in range(1,7)],'All five raw fresh confirmation times (ms).','lrrrrr')  # Preserve every indexed repetition.
task4+=r'''
\subsection{What the execution plans establish}
Q3's baseline scans transactions twice. The confirmed plan instead uses \texttt{t4\_team\_month\_type} bitmap index scans in both branches, each identifying 19,297 3 ROOM sales. This operator change supports the measured improvement. The date range covers all stored sales, so it is not selective; room type provides the filtering opportunity. A type-led or partial alternative remains worth testing on the intended native workload.

Q2's remaining-lease CASE expression classifies all transactions rather than searching a narrow lease interval. The lease index is unused. Q1 consumes 52,280 4/5 ROOM sales, and Q4--Q6 retain broad cohorts; none uses the confirmed optional indexes. Their output ordering and aggregates still cost work. Q4 continues to read the nearby primary-key index with an incremental sort; the separate nearest-order candidate changes that plan, but its measured total runtime does not justify claiming an overall improvement. Q6 sorts 195,690 sale-membership rows in the representative largest-data baseline. It remains dominated by membership expansion and aggregation, not a selective transaction lookup.

The relevant complete plans are stored under \texttt{evidence/run/plans}; compact node summaries and index inventories are under \texttt{evidence/run/configurations}. They record actual row counts, loops, heap fetches, buffers and sort details. A created index is considered used only when its name appears in an actual plan.
'''
task4+=f"\nThe confirmed three-index bundle occupies {final['extra_index_bytes']/2**20:.3f} MiB and takes {final['build_wall_ms']:.2f} ms of separate build wall time in this run. Build time is not included in SELECT timings. Extra indexes also require maintenance during future inserts and updates; the read-only experiment does not quantify that write penalty.\n"  # Include cost without extrapolating native storage speed.
task4+=r'''
\subsection{Deliverables and reproduction}
\texttt{SD6103\_Task4\_Results.xlsx} contains a formula-driven Summary sheet with an editable Excel bar chart, a Candidates sheet retaining all seven trials, and a Raw sheet containing all 390 observations. Means, sample deviations and reductions are calculated from raw measurements. The full raw CSV, SQL fingerprints, complete outputs, all timed plans, candidate outcomes and final index DDL accompany the workbook.

Annotated reproduction commands and dependency setup are in the package README. Both runners require an empty output folder. The native runner retains a fresh schema, repeats all trials, and selects indexes from native measurements. The macOS launcher supplies portable demo-database defaults.

\textbf{Submission boundary.} The merged queries, independent result checks and scoped WASM experiment are complete. Confirm acceptance of the 2023--2025 partition protocol and alternative tool, or run the prescribed historical-file/native procedure. Genuine pgAdmin captures must come from the native run when required; supplied figures are labelled result exports.

\subsection{References and provenance}
PostgreSQL 18 documentation: \url{https://www.postgresql.org/docs/18/sql-explain.html}; index-only scans, \url{https://www.postgresql.org/docs/18/indexes-index-only-scans.html}; partial indexes, \url{https://www.postgresql.org/docs/18/indexes-partial.html}.

Teammate source: \url{https://github.com/yzxfwdplf/SD6103-Data-Systems-Task3}. The archived snapshot records file-level blob SHAs and URLs, with the root tree labelled separately. Uploaded SQL, scoped-data manifests and validation evidence are preserved in the package.
'''
(REPORT/'SD6103_Merged_Task3_Task4.tex').write_text(prefix+perf+task4+'\n\\end{document}\n')  # Generate the complete merged report in the learned layout.
(REPORT/'SD6103_Task4.tex').write_text(preamble.replace(r'\setcounter{section}{3}',r'\setcounter{section}{4}')+'\\begin{document}\n'+task4+'\n\\end{document}\n')  # Deliver Task 4 separately for easy group insertion.
(REPORT/'workbook_inputs.json').write_text(json.dumps({'raw':rows,'candidates':candidates,'final':final,'baseline_means':base,'indexed_means':indexed},indent=2))  # Supply typed source inputs to the native Excel artifact builder.
print('Generated six checked result figures, two timing figures and two report sources.')  # Report completed artifact authoring.
