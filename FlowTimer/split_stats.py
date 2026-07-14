import os
import re

input_file = "FlowTimer/StatisticsView.swift"
with open(input_file, "r") as f:
    content = f.read()

# We need to split the file based on structure.
# I'll just write a quick script that extracts structs by matching `struct X` and finding its closing brace.

def extract_struct(name, content):
    pattern = rf"struct {name}[^\{{]*\{{"
    match = re.search(pattern, content)
    if not match:
        return None
    start_idx = match.start()
    
    # find matching brace
    brace_count = 0
    in_string = False
    escape = False
    
    for i in range(match.end() - 1, len(content)):
        c = content[i]
        if escape:
            escape = False
            continue
        if c == '\\':
            escape = True
            continue
        if c == '"':
            in_string = not in_string
            continue
            
        if not in_string:
            if c == '{':
                brace_count += 1
            elif c == '}':
                brace_count -= 1
                if brace_count == 0:
                    return content[start_idx:i+1]
    return None

structs_to_extract = [
    "StatisticsView",
    "EmptyStatisticsView",
    "StatisticsHeader",
    "StatisticsHeroCard",
    "StatisticsGoalCard",
    "CircularProgressRing",
    "StatisticsChartCard",
    "StatisticCard",
    "StatisticsTagsSection",
    "CardModifier",
    "ChartDataPoint",
    "PeriodStats",
    "ContinuousSession",
    "StatisticsPeriodCalculator"
]

extracted = {}
for s in structs_to_extract:
    extracted[s] = extract_struct(s, content)

# Also extract the extensions
def extract_extension(name, content):
    pattern = rf"extension {name}[^\{{]*\{{"
    match = re.search(pattern, content)
    if not match:
        return None
    start_idx = match.start()
    
    brace_count = 0
    in_string = False
    escape = False
    
    for i in range(match.end() - 1, len(content)):
        c = content[i]
        if escape:
            escape = False
            continue
        if c == '\\':
            escape = True
            continue
        if c == '"':
            in_string = not in_string
            continue
            
        if not in_string:
            if c == '{':
                brace_count += 1
            elif c == '}':
                brace_count -= 1
                if brace_count == 0:
                    return content[start_idx:i+1]
    return None

calendar_ext = extract_extension("Calendar", content)
period_enum = extract_struct("StatisticsPeriod", content) # wait, it's an enum
if not period_enum:
    # try enum
    match = re.search(r"enum StatisticsPeriod[^\{]*\{", content)
    if match:
        start_idx = match.start()
        brace_count = 0
        for i in range(match.end() - 1, len(content)):
            c = content[i]
            if c == '{': brace_count += 1
            elif c == '}': 
                brace_count -= 1
                if brace_count == 0:
                    period_enum = content[start_idx:i+1]
                    break

def write_file(name, imports, bodies):
    with open(f"Statistics/{name}.swift", "w") as f:
        for imp in imports:
            f.write(f"import {imp}\n")
        f.write("\n")
        f.write("\n\n".join(bodies))
        f.write("\n")

# StatisticsView.swift
write_file("StatisticsView", ["SwiftUI", "Charts"], [extracted["StatisticsView"]])

# StatisticsHeader.swift
write_file("StatisticsHeader", ["SwiftUI"], [extracted["StatisticsHeader"]])

# StatisticsHeroCards.swift
write_file("StatisticsHeroCards", ["SwiftUI"], [extracted["StatisticsHeroCard"], extracted["StatisticsGoalCard"], extracted["CircularProgressRing"]])

# StatisticsChartCard.swift
write_file("StatisticsChartCard", ["SwiftUI", "Charts"], [extracted["StatisticsChartCard"]])

# StatisticsMetricGrid.swift
write_file("StatisticsMetricGrid", ["SwiftUI"], [extracted["StatisticCard"]])

# StatisticsTagsSection.swift
write_file("StatisticsTagsSection", ["SwiftUI"], [extracted["StatisticsTagsSection"]])

# StatisticsEmptyState.swift
write_file("StatisticsEmptyState", ["SwiftUI"], [extracted["EmptyStatisticsView"]])

# StatisticsPeriodCalculator.swift
# Needs enum StatisticsPeriod, ChartDataPoint, PeriodStats, ContinuousSession, StatisticsPeriodCalculator, and CardModifier
write_file("StatisticsPeriodCalculator", ["SwiftUI"], [
    extracted["CardModifier"],
    period_enum,
    extracted["ChartDataPoint"],
    extracted["PeriodStats"],
    extracted["ContinuousSession"],
    extracted["StatisticsPeriodCalculator"],
    calendar_ext
])

print("Extraction complete.")
