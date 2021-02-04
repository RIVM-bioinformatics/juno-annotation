"""Generate sample sheet for AMR_annotation pipeline.

Usage:
  generate_sample_sheet.py <source_dir>

<source_dir> is a directory containing input fasta files with typical
filenames as used in the legacy (non-automated) process. Output will
be a sample sheet in YAML, for example:

  sample1_id:
    path/to/sample1_id_assembly.fasta
  ...
"""

import argparse
import pathlib
import re
import yaml
import os
import pandas as pd

fasta_pattern = re.compile("(.*?)(?:_assembly)?.fasta")

def main(args):
    assert args.dir.is_dir(), "Argument must be a directory."
    
    samples = {}
    for file_ in args.dir.iterdir():
        if file_.is_dir():
            continue
        match = fasta_pattern.fullmatch(file_.name)
        if match:
            sample = samples.setdefault(match.group(1), {})
            sample["fasta_file"] = str(file_)
    
    if args.metadata is not None :
        assert os.path.exists(args.metadata), "Provided metadata file does not exist"
        # Load species file
        species_file = pd.read_csv(args.metadata, index_col = 0, dtype={'Sample':str})
        species_file.index = species_file.index.map(str)
        species_file = species_file.transpose().to_dict()
        for sample_name in species_file:
            match = fasta_pattern.fullmatch(sample_name)
            if match:
                sample = str(match.group(1))
                if sample in samples:
                    samples[sample]["Genus"] = species_file[sample_name]["Genus"]
                    samples[sample]["Species"] = species_file[sample_name]["Species"]

    print(yaml.dump(samples, default_flow_style=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("dir", type=pathlib.Path, 
                       help="Directory where input files are located")
    parser.add_argument("--metadata", type=str, 
                       help=".csv file containing at least 3 columns: 'File_name', 'Genus' and 'Species'")
    main(parser.parse_args())
