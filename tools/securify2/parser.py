import json, io, tarfile
import sb.parse_utils
import re

VERSION = "2022/11/17"

FINDINGS = {
"Call to Default Constructor",
"External Calls of Functions",
"Taint Analysis for PASS Project",
"Uninitialized Local Variables",
"Solidity pragma directives",
"Gas-dependent Reentrancy",
"Unrestricted call to selfdestruct",
"Unrestricted write to storage",
"Locked Ether",
"Reentrancy with constant gas",
"Transaction Order Affects Execution of Ether Transfer",
"ERC20 Indexed Pattern",
"Right-to-left-override pattern",
"External call in loop",
"Incorrect ERC20 Interface",

"Multiplication after division",
"Missing Input Validation",
"Benign Reentrancy",
"No-Ether-Involved Reentrancy",
"Repeated Call to Untrusted Contract",
"Solidity Naming Convention",
"Shadowed Builtin",
"Shadowed Local Variable",
"Usage of block timestamp",
"State Variable Shadowing",
"Uninitialized State Variable",
"Constable State Variables",
"Dangerous Strict Equalities",
"Delegatecall or callcode to unrestricted address",
"Transaction Order Affects Ether Amount",
"Unrestricted Ether Flow",
"Transaction Order Affects Ether Receiver",
"Possibly unsafe usage of tx-origin",
"Unhandled Exception",
"Unused Return Pattern",
"Unused State Variable",
"Low Level Calls",
"Assembly Usage",
"Too Many Digit Literals",
"State variables default visibility"
}

CONTRACT  = re.compile("^INFO:root:[Cc]ontract ([^:]*):([^:]*):")
WEAKNESS  = re.compile("^INFO:symExec:[\s└>]*([^:]*):\s*True")
LOCATION1 = re.compile("^INFO:symExec:([^:]*):([0-9]+):([0-9]+):\s*([^:]*):\s*(.*)\.")
LOCATION2 = re.compile("^([^:]*):([^:]*):([0-9]+):([0-9]+)")
COMPLETED = re.compile("^INFO:symExec:\s*====== Analysis Completed ======")



def parse(exit_code, log, output):
    findings, infos = [], set()
    errors, fails = set(), set()
    errors, fails = sb.parse_utils.errors_fails(exit_code, log, log_expected=False)
    if fails:
        errors.discard("EXIT_CODE_1")
    # log1 = log.read()
    pattern = re.compile(r'Severity:\s*([^\n]+)\nPattern:\s*([^\n]+)[\s\S]+?Line:\s*(\d+)', re.MULTILINE)
    
    if hasattr(log, 'read'):
        log = log.read()
    # Join the log content if it is a list
    elif isinstance(log, list):
        log = '\n'.join(log)
    
    
    
    matches = pattern.findall(log)
    findings = []
    for match in matches:
        finding = {
            'Severity': match[0],
            'name': match[1],
            'line': int(match[2])
        }
        findings.append(finding)

    return findings, infos, errors, fails


if __name__ == '__main__':
    with open ('/home/kaixuan/web3/sast-study/result/SolidiFI-benchmark/securify2/20230314_0705/datasets/SolidiFI-benchmark/buggy_contracts/Overflow-Underflow/buggy_2.sol/result.log', 'r') as f:
        findings, infos, errors, fails = parse(0, f, None)
        print(findings)