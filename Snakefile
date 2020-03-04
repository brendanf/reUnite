import os.path
import re
import subprocess
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider

HTTP = HTTPRemoteProvider()

# For testing, parse the yaml file (this is automatically done by Snakemake)
#import yaml
#with open("config/config.yaml", 'r') as ymlfile: config = yaml.safe_load(ymlfile)

configfile: "config/config.yaml"

# Find the maximum number of cores available to a single node on SLURM,
# or if we aren't in a SLURM environment, how many we have on the local machine.
try:
    maxthreads = max([int(x) for x in re.findall(r'\d+', subprocess.check_output(["sinfo", "-O", "cpus"]).decode())])
except FileNotFoundError:
    maxthreads = int(subprocess.check_output("nproc").decode())

#### Reference databases ####

# generate taxonomy translation files
localrules: translate_references
rule translate_references:
  output:
        expand("{outdir}/{db}.{region}.{method}.fasta.gz",
               outdir = config['outdir'],
               db = ['warcup', 'unite'],
               region = ['ITS'],
               method = ['sintax', 'dada2']),
        expand("{outdir}/{db}.{region}.{method}.fasta.gz",
               outdir = config['outdir'],
               db = ['rdp_train'],
               region = ['LSU'],
               method = ['sintax', 'dada2'])
  input:
    expand("{refdir}/{dbname}.{type}",
           refdir = config['refdir'],
           dbname = ['rdp_train', 'warcup', 'unite'],
           type = ['fasta.gz', 'pre.sed']),
    "{rdir}/taxonomy.R".format_map(config),
    regions = config["regions_file"],
    tedersoo = "{refdir}/Tedersoo_Eukarya_classification.xlsx".format_map(config),
    tedersoo_patch = config['tedersoo_patch'],
    script = "{rdir}/make_taxonomy.R".format_map(config)
  resources:
    walltime = 60
  conda: "{condadir}/drake.yaml".format_map(config)
  log: "{logdir}/translate_references.log".format_map(config)
  script: "{rdir}/make_taxonomy.R".format_map(config)    

# Download the Unite database
localrules: unite_download
rule unite_download:
    output: "{refdir}/unite.fasta.gz".format_map(config)
    input:
      zip = HTTP.remote(config['unite_url'], allow_redirects = True, keep_local = True)
    shadow: "shallow"
    shell:
        """
        echo {config[unite_md5]} {input} |
        md5sum -c - &&
        mkdir -p $(dirname {output}) &&
        unzip {input} &&
        gzip -c {config[unite_filename]} > {output}
        """

# Download the RDP fungal LSU training set
# This will also convert all sequences from RNA (Uu) to DNA (Tt)
localrules: rdp_download
rule rdp_download:
    output:
        fasta = "{refdir}/rdp_train.fasta.gz".format_map(config),
        taxa  = "{refdir}/rdp_train.taxa.txt".format_map(config)
    input:
      zip = HTTP.remote(config['rdp_url'], allow_redirects = True, keep_local = True)
    shadow: "shallow"
    shell:
        """
        echo {config[rdp_md5]} {input.zip} |
        md5sum -c - &&
        mkdir -p $(dirname {output.fasta}) &&
        unzip {input.zip} &&
        sed '/^>/!y/uU/tT/' <{config[rdp_filename]} |
        gzip -c > {output.fasta} &&
        mv {config[rdp_taxa]} {output.taxa}
        """

# Download the Warcup fungal ITS training set
localrules: warcup_download
rule warcup_download:
    output:
        fasta = "{refdir}/warcup.fasta.gz".format_map(config),
        taxa  = "{refdir}/warcup.taxa.txt".format_map(config)
    input:
      zip = HTTP.remote(config['warcup_url'], allow_redirects = True, keep_local = True)
    shadow: "shallow"
    shell:
        """
        echo {config[warcup_md5]} {input} |
        md5sum -c - &&
        mkdir -p $(dirname {output.fasta}) &&
        unzip {input} &&
        gzip -c {config[warcup_filename]} > {output.fasta} &&
        mv {config[warcup_taxa]} {output.taxa}
        """

# Download Eukarya classification system proposed by Tedersoo
localrules: tedersoo_classification
rule tedersoo_classification:
    output: "{refdir}/Tedersoo_Eukarya_classification.xlsx".format_map(config)
    input: HTTP.remote(config['tedersoo_url'], allow_redirects = True)
    shadow: "shallow"
    shell:
        """
        echo {config[tedersoo_md5]} {input} |
        md5sum -c - &&
        mv {input} {output}
        """
