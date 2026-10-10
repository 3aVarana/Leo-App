#!/usr/bin/env python3
"""Scores harness output with rule-based checks. See README.md.

    python3 scripts/exercise-eval/score.py before.txt after.txt

Prints one table row per file. The checks mirror the app's repair and rejection rules
(docs/Leo-Exercise-Quality-Plan.md, section 2.4), plus passages under the requested range and
question wording copied into the correct answer only. Accepted exercises have already been
repaired and validated by the app, so on current code most columns should read 0; failures
include the exercises the app rejected.
"""

import re
import sys

# Section 2.4's phrase lists, plus a few looser English patterns the baseline counted.
SELF_REFERENCE = re.compile(
    r"\b(the author|the writer|the passage|the text|the main idea|this shows|this passage"
    r"|el autor|la autora|el texto|el pasaje|la idea principal"
    r"|o autor|a autora|o texto|a passagem|a ideia principal"
    r"|central (idea|message)|wanted to show)\b",
    re.I,
)
MARKDOWN = re.compile(r"[*`]|(^|\s)_\w|\w_(\s|$)|^#", re.M)
TERMINAL = re.compile(r"[.!?»”\"')]$")

# The requested passage range per age group, from AgeGroup.passageWordRange.
REQUESTED = {"6-8": (50, 80), "9-11": (80, 120), "12-14": (100, 150), "15-17": (120, 180), "18+": (160, 230)}

COLUMNS = [
    ("n", "exercises"),
    ("failed", "failed"),
    ("self_reference", "self-ref"),
    ("markdown", "markdown"),
    ("standout", "standout"),
    ("longest", "longest+25%"),
    ("punctuation", "punct"),
    ("leak", "q-leak"),
    ("truncated", "expl cut"),
    ("under", "under range"),
]


def parse(path):
    blocks = open(path, encoding="utf-8").read().split("\n===== ")[1:]
    exercises = []
    for block in blocks:
        header = block.split("\n")[0]
        age = re.match(r"\[(\S+) \|", header).group(1)
        if "FAILED" in header:
            exercises.append({"failed": True, "age": age})
            continue

        def field(key):
            match = re.search(rf"^{key}: (.*)$", block, re.M)
            return match.group(1) if match else ""

        options = re.findall(r"^  ([*-]) (.*)$", block, re.M)
        exercises.append({
            "failed": False,
            "age": age,
            "words": int(re.search(r"words=(\d+)", header).group(1)),
            "passage": field("PASSAGE"),
            "question": field("Q"),
            "correct": next(text for mark, text in options if mark == "*"),
            "distractors": [text for mark, text in options if mark == "-"],
            "explanation": field("EXPLANATION"),
        })
    return exercises


def words(text):
    return len(text.split())


def content_words(text):
    return set(re.findall(r"\w{5,}", text.lower()))


def score(exercises):
    counts = {key: 0 for key, _ in COLUMNS}
    for exercise in exercises:
        counts["n"] += 1
        if exercise["failed"]:
            counts["failed"] += 1
            continue
        correct, distractors = exercise["correct"], exercise["distractors"]
        longest_distractor = max(words(d) for d in distractors)
        if SELF_REFERENCE.search(exercise["passage"]):
            counts["self_reference"] += 1
        if MARKDOWN.search(exercise["passage"]):
            counts["markdown"] += 1
        # Section 2.4's rejection rule.
        if words(correct) > longest_distractor * 1.5 and words(correct) >= longest_distractor + 3:
            counts["standout"] += 1
        # The looser "clearly longest" count of the baseline tables.
        if words(correct) > longest_distractor * 1.25:
            counts["longest"] += 1
        endings = {text.rstrip()[-1:] in ".!?" for text in [correct] + distractors}
        if len(endings) > 1:
            counts["punctuation"] += 1
        question = content_words(exercise["question"])
        shared = len(question & content_words(correct))
        if shared >= 2 and shared > max(len(question & content_words(d)) for d in distractors) + 1:
            counts["leak"] += 1
        if exercise["explanation"] and not TERMINAL.search(exercise["explanation"].strip()):
            counts["truncated"] += 1
        if exercise["words"] < REQUESTED[exercise["age"]][0]:
            counts["under"] += 1
    return counts


def main(paths):
    if not paths:
        sys.exit(__doc__)
    print("| file | " + " | ".join(label for _, label in COLUMNS) + " |")
    print("|---|" + "---:|" * len(COLUMNS))
    for path in paths:
        counts = score(parse(path))
        print(f"| {path} | " + " | ".join(str(counts[key]) for key, _ in COLUMNS) + " |")


if __name__ == "__main__":
    main(sys.argv[1:])
