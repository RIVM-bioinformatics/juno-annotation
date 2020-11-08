#############################################################################
#####                       Annotation                                  #####
#############################################################################

rule update_tbl2asn:
    input:
        expand(OUT + "/filtered_contigs/{sample}.fasta", sample = SAMPLES)
    output:
        temp("tbl2asn")
    threads: 1
    conda:
        "../../envs/prokka.yaml"
    log:
        OUT + "/log/prokka/update_tbl2asn.log"
    shell:
        """
wget https://ftp.ncbi.nih.gov/toolbox/ncbi_tools/converters/by_program/tbl2asn/linux64.tbl2asn.gz &> {log}
gunzip linux64.tbl2asn.gz &>> {log}
mv linux64.tbl2asn tbl2asn &>> {log}
cp tbl2asn `which tbl2asn` &>> {log}
        """