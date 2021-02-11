#!/usr/bin/env bats

## General Juno tests

@test "Printing help" {
  printed_help=`bash start_annotation.sh -h`
  [[ "${printed_help}" =~ "-i, --input [DIR]                 This is the folder containing" ]]
}

@test "Make sample sheet from input directory that does not contain either fasta or fastq files" {
  python bin/generate_sample_sheet.py tests/ > tests/test_sample_sheet.yaml
  sample_sheet_errors=`diff --suppress-common-lines tests/test_sample_sheet.yaml tests/example_output/wrong_sample_sheet.yaml`
  [[ -z $sample_sheet_errors ]]
  rm -f tests/test_sample_sheet.yaml
}

@test "Make sample sheet from fasta input" {
  python bin/generate_sample_sheet.py tests/example_fasta_input/ --metadata tests/example_output/example_metadata.csv > tests/test_sample_sheet.yaml
  sample_sheet_errors=`diff --suppress-common-lines tests/test_sample_sheet.yaml tests/example_output/fasta_sample_sheet.yaml`
  [[ -z $sample_sheet_errors ]]
  rm -f tests/test_sample_sheet.yaml
}

@test "Make metadata" {
  python bin/guess_species.py tests/example_fasta_input/
  [[ $(grep "sample1_Kpn.fasta,Klebsiella,pneumoniae" metadata.csv) == "sample1_Kpn.fasta,Klebsiella,pneumoniae" ]]
  [[ $(grep "samp2_Eco.fasta,Escherichia,coli" metadata.csv) == "samp2_Eco.fasta,Escherichia,coli" ]]
  rm -f metadata.csv
}

## Specific for AMR_annotation

@test "Test full pipeline (dry run)" {
  bash start_annotation.sh -i tests/example_fasta_input/ --metadata tests/example_output/example_metadata.csv --proteins tests/files/db.fasta -y -n
  [[ "$status" -eq 0 ]]
}

@test "Check full pipeline if running locally (and test samples present)" {
  if [ -f "/mnt/db/amr_annotation_db/refseq_plasmids/db_wgenenames_refseq.fasta" ]; then
      bash start_annotation.sh -i tests/example_fasta_input/ --metadata tests/example_output/example_metadata.csv -y
  else
      skip
  fi
  [[ "$status" -eq 0 ]]
}
