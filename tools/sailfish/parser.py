import io, tarfile, json, re
import sb.parse_utils

VERSION = "2024/04/30"

FINDINGS = {
}

LOCATION = re.compile("/sb/(.*?)#([0-9-]*)")

def parse(exit_code, log, output):
    findings, infos = [], set()
    errors, fails = sb.parse_utils.errors_fails(exit_code, log)

    #for line in log:
    #    pass

    try:
        with io.BytesIO(output) as o, tarfile.open(fileobj=o) as tar:
            output_json = tar.extractfile("output.json").read()
            issues = json.loads(output_json)["results"]["detectors"]
    except Exception as e:
        fails.add(f"error parsing results: {e}")
        issues = {}
    # print(issues[0])
    for issue in issues:
        finding = {}
        for i,f in ( ("check", "name"), ("impact", "impact" ),
            ("confidence", "confidence"), ("description", "message")):
            finding[f] = issue[i]
        elements = issue.get("elements",[])
        m = LOCATION.search(finding["message"])
        finding["message"] = finding["message"].replace("/sb/","")
        if m:
            finding["filename"] = m[1]
            if "-" in m[2]:
                start,end = m[2].split("-")
                finding["line"] = int(start)
                finding["line_end"] = int(end)
            else:
                finding["line"] = int(m[2])
        elif len(elements) > 0 and "source_mapping" in elements[0]:
            source_mapping = elements[0]["source_mapping"]
            lines = sorted(source_mapping["lines"])
            if len(lines) > 0:
                finding["line"] = lines[0]
                if len(lines) > 1:
                    finding["line_end"] = lines[-1]
            finding["filename"] = source_mapping["filename"]
        for element in elements:
            if element.get("type") == "function":
                finding["function"] = element["name"]
                ### may cause key error for filename_used
                if "filename_used" in element["source_mapping"]:
                    
                    finding["contract"] = element["source_mapping"]["filename_used"]
                    print(f"filename_used found in {element['source_mapping']}")
                    import time
                    time.sleep(10)
                else:
                    # print(f"filename_used not found in {element['source_mapping']}")
                    # ### print the keys in element["source_mapping"]
                    # print(element["source_mapping"].keys())
                    # dict_keys(['start', 'length', 'filename_relative', 'filename_absolute', 'filename_short', 'is_dependency', 'lines', 'starting_column', 'ending_column'])
                    # import time
                    # time.sleep(10)
                    finding["contract"] = element["source_mapping"]["filename_absolute"]
                break
        findings.append(finding)

    return findings, infos, errors, fails
