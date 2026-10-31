from pathlib import Path  # Resolve the scoped data and evidence locations.
import argparse  # Allow validation of a separate native-server rerun.
import hashlib  # Match each timing to the exact measured SQL.
import json  # Save independent validation evidence.
import numpy as np  # Classify lease and distance bands independently.
import pandas as pd  # Recompute all six analytical results from CSVs.

ROOT=Path(__file__).resolve().parents[1]  # Locate the package root.

def main():  # Run a computation independent of PostgreSQL query execution.
    ap=argparse.ArgumentParser()  # Accept a different completed evidence directory.
    ap.add_argument('--run',type=Path,default=ROOT/'evidence/run')  # Default to the new WASM experiment.
    run=ap.parse_args().run  # Select the evidence to validate.
    d=ROOT/'data/processed'  # Read only the 2023-2025 instance.
    tx=pd.read_csv(d/'resale_transaction.csv')  # Load the 78,670 retained observations.
    f=pd.read_csv(d/'hdb_flat.csv')  # Load participating address records.
    t=pd.read_csv(d/'town.csv')  # Load town identifiers and names.
    n=pd.read_csv(d/'nearby.csv')  # Load the audited retained distances.
    h=pd.read_csv(d/'hawker_centre.csv')  # Load the reference market-stall counts.
    assert tx.sale_month.ge('2023-01-01').all() and tx.sale_month.lt('2026-01-01').all()  # Reject any out-of-period sale.
    assert tx.sale_month.str[:7].nunique()==36  # Confirm complete month coverage.
    tx=tx.merge(f[['flat_id','town_id']],on='flat_id',validate='many_to_one').merge(t,on='town_id',validate='many_to_one')  # Attach town names without multiplication.
    tx['psm']=tx.resale_price/tx.floor_area_sqm  # Compute each sale's price per square metre.
    tx['sale_year']=tx.sale_month.str[:4].astype(int)  # Group annual maxima by calendar year.
    reports=[]  # Collect explicit validation results for each query.
    def compare(q,expected,keys):  # Compare keys, counts and displayed numerical values.
        actual=pd.read_csv(run/f'results/baseline_S5_Q{q}.csv').sort_values(keys).reset_index(drop=True)  # Read the complete executed SQL output.
        expected=expected[actual.columns].sort_values(keys).reset_index(drop=True)  # Align columns and groups deterministically.
        assert len(actual)==len(expected),f'Q{q} result count'  # Require the same number of groups.
        for c in actual:  # Check every output column.
            if c in keys:  # Require exact group identity.
                assert actual[c].astype(str).tolist()==expected[c].astype(str).tolist(),f'Q{q} key {c}'  # Reject missing or extra groups.
            else:  # Compare independently recomputed numbers.
                tolerance=0 if ('count' in c or 'volume' in c) else .011  # Counts are exact; displayed values allow cent rounding.
                assert np.allclose(pd.to_numeric(actual[c]),pd.to_numeric(expected[c]),atol=tolerance,rtol=0),f'Q{q} value {c}'  # Reject any substantive mismatch.
        reports.append({'query':q,'passed':True,'rows':len(actual)})  # Preserve each successful check.
    x=tx[tx.flat_type.isin(['4 ROOM','5 ROOM'])]  # Independently select Q1's required room types.
    e=x.groupby(['town_name','flat_type']).agg(avg_price_per_sqm=('psm','mean'),transaction_count=('transaction_id','size')).reset_index()  # Recompute per-sale ratio means.
    compare(1,e,['town_name','flat_type'])  # Validate Q1.
    tx['lease_bucket']=np.where(tx.remaining_lease_months<600,'< 50 years',np.where(tx.remaining_lease_months<840,'50 to < 70 years','70+ years'))  # Assign the disjoint lease buckets.
    e=tx.groupby(['town_name','lease_bucket']).agg(median_resale_price=('resale_price','median'),avg_price_per_sqm=('psm','mean'),transaction_volume=('transaction_id','size')).reset_index()  # Recompute medians and volumes.
    compare(2,e,['town_name','lease_bucket'])  # Validate Q2.
    x=tx[tx.flat_type.eq('3 ROOM')]  # Use the required type for both stages of Q3.
    rank=x.groupby('town_id').floor_area_sqm.mean().reset_index(name='avg_3room_floor_area_sqm').sort_values(['avg_3room_floor_area_sqm','town_id'],ascending=[False,True]).head(10)  # Rank the same three-year sample.
    e=x.merge(rank,on='town_id').groupby(['town_name','sale_year','avg_3room_floor_area_sqm']).resale_price.max().reset_index(name='highest_resale_price')  # Recompute each annual maximum.
    compare(3,e,['town_name','sale_year'])  # Validate Q3 and its thirty town-year groups.
    n['proximity_class']=np.where(n.distance_m<500,'near',np.where(n.distance_m<1000,'medium','far'))  # Independently classify distances.
    nearest=n.sort_values(['flat_id','distance_m','hawker_id']).drop_duplicates('flat_id')  # Resolve nearest-centre ties by key.
    x=tx.merge(nearest[['flat_id','proximity_class']],on='flat_id')  # Attach only one proximity class per sale.
    e=x.groupby(['town_name','flat_type','proximity_class']).resale_price.mean().unstack().dropna(subset=['near','far']).reset_index()  # Require near and far groups.
    e['price_diff_percentage']=(e['near']-e['far'])*100/e['far']  # Use unrounded group means.
    e=e.rename(columns={'town_name':'town','near':'avg_price_near_hawker','far':'avg_price_far_hawker'})  # Match the required output labels.
    compare(4,e,['town','flat_type'])  # Validate Q4.
    nh=n.merge(h[['hawker_id','market_stall_count']],on='hawker_id',validate='many_to_one')  # Attach the reference stall counts.
    eligible=nh[nh.market_stall_count.gt(0)][['flat_id','proximity_class']].drop_duplicates()  # Keep one qualifying address/class pair.
    q5_stages=[]  # Check the fixed budget at every measured size.
    tx['load_stage']=tx.source_row_key.map(lambda s:int(s[:16],16)%5+1)  # Reconstruct the exact in-period partition rule.
    for s in range(1,6):  # Independently check all five cumulative populations.
        x=tx[tx.load_stage.le(s)].merge(eligible,on='flat_id')  # Join only unique class memberships.
        unfiltered=x.groupby(['town_name','proximity_class']).agg(avg_resale_price=('resale_price','mean'),transaction_count=('transaction_id','size')).reset_index()  # Recompute before the budget filter.
        e=unfiltered[unfiltered.avg_resale_price.gt(700000)]  # Apply one fixed budget for every size.
        got=pd.read_csv(run/f'results/baseline_S{s}_Q5.csv')  # Read that stage's actual result.
        assert set(map(tuple,e[['town_name','proximity_class']].values))==set(map(tuple,got[['town_name','proximity_class']].values))  # Match every passing group.
        assert 0<e.town_name.nunique()<unfiltered.town_name.nunique()  # Require a nonempty, non-universal town selection.
        q5_stages.append({'size':f'S{s}','result_rows':len(e),'passing_towns':int(e.town_name.nunique()),'eligible_towns':int(unfiltered.town_name.nunique())})  # Save all five checks.
    compare(5,e,['town_name','proximity_class'])  # Validate full-data means and counts for Q5.
    nh['fresh_market_status']=np.where(nh.market_stall_count.isna(),'unknown',np.where(nh.market_stall_count.gt(0),'yes','no'))  # Preserve missing evidence separately.
    member=nh[['flat_id','proximity_class','fresh_market_status']].drop_duplicates()  # Define distinct group membership.
    totals=tx.groupby(['flat_id','town_name']).agg(n=('transaction_id','size'),price_sum=('resale_price','sum')).reset_index()  # Aggregate transactions before the spatial join.
    x=totals.merge(member,on='flat_id')  # Use a computational route different from the SQL.
    e=x.groupby(['town_name','proximity_class','fresh_market_status']).agg(flat_count=('flat_id','size'),transaction_count=('n','sum'),price_sum=('price_sum','sum')).reset_index()  # Combine per-address sums and counts.
    e['avg_resale_price']=e.price_sum/e.transaction_count  # Use correctly weighted group means.
    compare(6,e,['town_name','proximity_class','fresh_market_status'])  # Validate Q6.
    raw=pd.read_csv(run/'measurements_raw.csv')  # Read the new timing observations.
    assert len(raw[raw.phase.eq('task3')])==150 and raw.groupby(['configuration','size_level','query_no']).size().eq(5).all()  # Require the complete experiment.
    assert not raw.duplicated(['configuration','size_level','query_no','repetition']).any()  # Reject duplicate timing records.
    for q in range(1,7):  # Check the exact executable text measured for each query.
        digest=hashlib.sha256((ROOT/f'sql/queries/Q{q}.sql').read_bytes()).hexdigest()  # Include the displayed trailing comments.
        assert raw.loc[raw.query_no.eq(q),'sql_sha256'].eq(digest).all()  # Reject timings of different query text.
    assert sum(pd.read_csv(run/'results/baseline_S5_Q2.csv').transaction_volume)==len(tx)  # Reconcile Q2's complete partition.
    checked_configs=[]  # Verify all exported index outputs independently of the runner's check.
    for config in raw.configuration.unique():  # Include every isolated candidate and final confirmation.
        if config=='baseline': continue  # The baseline was independently recomputed above.
        for q in range(1,7):  # Require every output cell to remain unchanged.
            base=pd.read_csv(run/f'results/baseline_S5_Q{q}.csv')  # Read the recomputed baseline output.
            current=pd.read_csv(run/f'results/{config}_S5_Q{q}.csv')  # Read the indexed output.
            order=list(base.columns)  # Compare complete rows, not only group counts.
            pd.testing.assert_frame_equal(base.sort_values(order).reset_index(drop=True),current.sort_values(order).reset_index(drop=True),check_exact=True)  # Indexes must not change numerical results.
        checked_configs.append(config)  # Retain checked configuration names.
    summary=pd.read_csv(run/'benchmark_summary.csv')  # Recompute statistics from raw observations.
    stats=raw.groupby(['configuration','size_level','query_no']).execution_ms.agg(['mean','std']).reset_index().merge(summary,on=['configuration','size_level','query_no'])  # Align each five-repeat group.
    assert np.allclose(stats['mean'],stats.mean_ms,atol=1e-9,rtol=0) and np.allclose(stats['std'],stats.sd_ms,atol=1e-9,rtol=0)  # Validate both mean and sample SD.
    result={'all_indexed_outputs_unchanged':checked_configs,'all_six_passed':True,'checks':reports,'transactions':len(tx),'months':36,'q5_budget':700000,'q5_stages':q5_stages,'task3_measurements':150,'total_measurements':len(raw),'sql_hashes_match':True}  # Summarize the actual checks.
    (run/'independent_validation.json').write_text(json.dumps(result,indent=2))  # Save the audit evidence.
    print(json.dumps(result,indent=2))  # Display the validation outcome.

if __name__=='__main__':  # Execute validation when called directly.
    main()  # Recompute and compare every full-data query.
