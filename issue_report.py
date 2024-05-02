import os
import pandas as pd

precision_df = pd.read_csv('/home/kaixuan/sast_study/solidity/smartbugs/precision_loss.csv')

toolids = precision_df['toolid'].unique()

from tqdm import tqdm


## we finally need to polish the tp results by using a good-looking table-like print.

tp_results = {}
recall_results = {}


for toolid in tqdm(toolids):
    print("Toolid: ", toolid)
    tool_df = precision_df[precision_df['toolid'] == toolid]
    print("Tool_df shape: ", tool_df.shape)
    
    
    ### used for vuln type mappings #####
    ### collect all issues within tool_df
    issues_report = set()
    ## use lambda to get the issues and split them and add them to the set
    tool_df['findings'].apply(lambda x: issues_report.update(x.split(',') if isinstance(x, str) else []))
    print("Issues report: ", issues_report)
    