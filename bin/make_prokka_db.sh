###############################################################################################################################################
### Annotation pipeline - Make database                                                                                                                     ### 
### Author: Alejandra Hernandez-Segura                                                                                                      ### 
### Organization: Rijksinstituut voor Volksgezondheid en Milieu (RIVM)                                                                      ### 
### Department: Infektieziekteonderzoek, Diagnostiek en Laboratorium Surveillance (IDS), Bacteriologie (BPD)                                ### 
### Date: 03-02-2021                                                                                                                        ### 
###                                                                                                                                         ### 
### Documentation: https://github.com/AleSR13/AMR_annotation.git                                                                            ### 
###                                                                                                                                         ### 
###                                                                                                                                         ### 
### Database downloaded from RefSeq and then modified to make it compatible with Prokka (including gene names)                              ### 
###                                                                                                                                         ###
###############################################################################################################################################

INPUT_DIR="$1"

set -euo pipefail

cd "$INPUT_DIR"
find . -maxdepth 1 -type f -name "*nonredundant*" -delete

# Download the database
wget ftp://ftp.ncbi.nlm.nih.gov/refseq/release/plasmid/*nonredundant*.faa.gz
wget ftp://ftp.ncbi.nlm.nih.gov/refseq/release/plasmid/*nonredundant*.gpff.gz

# Gunzip all the protein.nonredundant files
find . -maxdepth 1 -type f -name '*nonredundant*.gz' -exec gunzip {} \;

# Make a multifasta
cat *.faa > all_plasmid.nonredundant_proteins.fasta
cat *.gpff > all_plasmid.nonredundant_proteins.gpff

# Get gene information from the gpff files
sed '/^DEFINITION/{N;s/\n           //;}' all_plasmid.nonredundant_proteins.gpff | \
grep "DEFINITION\|/gene=" | \
sed "s/\[.*//g" | \
awk '/gene="/ { print f $0 } {f=$0}' | \
sed 's/                     \/gene//g' | \
sed 's/"$//g' > intermediate1.txt

awk -F  '="' ' { t = $1; $1 = $2; $2 = t; print; } ' intermediate1.txt | \
sed 's/ DEFINITION  /~~~/g' | \
sed '/~$\|: $/d' | \
sort | \
uniq -d > intermediate2.txt

# Add gene information and re-format the fasta file to make it compatible with prokka
rm -f db_refseq_includinggenenames.fasta

while read line; do
  if [[ $line =~ ^\>WP && ! $line =~ hypothetical ]]; then
    protein_name=`echo ${line#*.[0-9] }`
    protein_name=`echo ${protein_name%[*\]}`
    if grep -q "~~~${protein_name} $" intermediate2.txt ; then
      replacement=`grep -h "~~~${protein_name} $" intermediate2.txt`
      line=${line/${protein_name} /~~~${replacement}}
    fi
  fi
  echo $line >> db_refseq_includinggenenames.fasta
done <all_plasmid.nonredundant_proteins.fasta

rm -f intermediate*
find . -maxdepth 1 -type f -name '*nonredundant*.faa' -delete
find . -maxdepth 1 -type f -name '*nonredundant*.gpff' -delete

echo "\n\nThe database has been made and can be accessed here: ${INPUT_DIR}/db_refseq_includinggenenames.fasta\n\n"