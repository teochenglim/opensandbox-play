"""Reads /workspace/input.txt (or generates sample data) and writes a report."""
import pathlib

input_path = pathlib.Path("/workspace/input.txt")

if input_path.exists():
    text = input_path.read_text()
else:
    # Generate sample data when no input is provided
    import random, string
    words = ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
             "sandbox", "cloud", "python", "stream", "file", "egress", "policy"]
    text = "\n".join(
        " ".join(random.choices(words, k=random.randint(5, 12)))
        for _ in range(100)
    )

lines = text.splitlines()
all_words = text.split()
unique_words = set(w.lower().strip(".,!?") for w in all_words)

print(f"  Lines processed: {len(lines)}")
print(f"  Words: {len(all_words)}")
print(f"  Unique words: {len(unique_words)}")

report = (
    "=== Analysis Report ===\n"
    f"Lines: {len(lines)}  Words: {len(all_words)}  Unique: {len(unique_words)}\n"
)
pathlib.Path("/workspace/report.txt").write_text(report)
