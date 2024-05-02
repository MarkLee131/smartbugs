import os
import pandas as pd

all_csv = '/home/kaixuan/sast_study/solidity/smartbugs/pocshift_result_all.csv'

label_csv = '/home/kaixuan/sast_study/solidity/smartbugs/pocshift_result_label.csv'

all_df = pd.read_csv(all_csv)
label_df = pd.read_csv(label_csv)

### only the label, filename columns are needed
label_df = label_df[['label', 'filename']].dropna()
### drop the duplicates
label_df.drop_duplicates(subset=['label', 'filename'], inplace=True)

print(label_df.shape, label_df.columns)
unique_types = label_df['label'].unique()
# print(unique_types)

# labels = {'logic flaw', 'public_burn', 'is_prodigal_vulnerable',
#  'weak random number generation', 'skim'}

vuln_mappings = {
    "logic_flaw": {"logic_flaw", "olympus-dao-staking-incorrect-call-order"},
    "public_burn": {"public_burn", "erc20-public-burn"},
    # "is_prodigal_vulnerable": {"is_prodigal_vulnerable"}, 
    "weak random number generation": {"weak_prng", "Warning_BLOCKHASH_instruction_used", "dependence_on_predictable_environment_variable_swc_120"},
    "skim": {"skim"}
}



### add labels to all_df according to label_df's column 'label' and 'filename'

final_df = pd.merge(all_df, label_df, on='filename', how='left')


print("After merging: ", final_df.shape, final_df.columns)

## drop the rows with the empty label
final_df.dropna(subset=['label'], inplace=True)
print("After dropping the empty labels: ", final_df.shape)

final_df.to_csv('/home/kaixuan/sast_study/solidity/smartbugs/pocshift_result_all_label.csv', index=False)

## categorize the vulnerabilities according to the toolids
toolids = final_df['toolid'].unique()

from tqdm import tqdm


## we finally need to polish the tp results by using a good-looking table-like print.

tp_results = {}
recall_results = {}


for toolid in tqdm(toolids):
    print("Toolid: ", toolid)
    tool_df = final_df[final_df['toolid'] == toolid]
    print("Tool_df shape: ", tool_df.shape)
    
    
    ### used for vuln type mappings #####
    ### collect all issues within tool_df
    issues_report = set()
    ## use lambda to get the issues and split them and add them to the set
    tool_df['findings'].apply(lambda x: issues_report.update(x.split(',') if isinstance(x, str) else []))
    print("Issues report: ", issues_report)
    
    ### set a interactive key for each iteration:
    # if the interactive key is not 'q', then continue the iteration
    # else go on for this iteration
    # inputs = "c"
    # inputs = input("Press any key to continue, 'q' to quit: ")
    # if inputs == 'q':
    #     break
    
    
#     #### calculate the true positive #####
#     #### determine the true positive by the label and the findings (need to convert them to vuln types by using
#     #### the vuln_mappings)
#     tp = 0
    
#     for index, row in tool_df.iterrows():
#         findings = row['findings'].split(',') if isinstance(row['findings'], str) else []
#         label = row['label']
        
#         ## convert the findings to vuln types
#         vuln_types = set()
#         for finding in findings:
#             for vuln_type, vuln_set in vuln_mappings.items():
#                 if finding in vuln_set:
#                     vuln_types.add(vuln_type)
        
#         ## if the label is in the vuln_types, then it is a true positive
#         if label in vuln_types:
#             tp += 1
#     tp_results[toolid] = tp
#     print("True positive: ", tp)
#     recall = str(tp / (len(tool_df) *1.0) * 100) + "%"
#     recall_results[toolid] = recall
#     print("Recall: ", recall)
    
# ## print the tp results in a table-like format, and use right-justified format

# print("Toolid".rjust(20), "True Positive".rjust(20), "All Vuln.".rjust(20), "Recall".rjust(20))
# print("".rjust(60, '-'))
# for toolid, tp in tp_results.items():
#     print(toolid.rjust(20), str(tp).rjust(20), str(len(final_df[final_df['toolid'] == toolid])).rjust(20), recall_results[toolid].rjust(20))
# print("".rjust(60, '-'))
    