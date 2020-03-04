#convert to DNA
/^>/!y/uU/tT/

#fill missing ranks with "unidentified X"
#/^>/ { s/Root(;[^;]+)$/&unidentified \1/
#       s/Root(;[^;]+)(;[^;]+)$/&unidentified \2/
#       s/Root(;[^;]+){2}(;[^;]+)$/&unidentified \2/
#       s/Root(;[^;]+){3}(;[^;]+)$/&unidentified \2/
#       s/Root(;[^;]+){4}(;[^;]+)$/&unidentified \2/
#       s/(unidentified )+/unidentified /g }

#spelling
#s/incertae([ _])sedos/incertae\1sedis/g

#Match Unite 
#s/Animalia;Metazoa/Metazoa/

#Rosling et al 2011
s/(;Taphrinomycotina incertae sedis){3} -soil clone group 1/;Archaeorhizomycetales;Archaeorhizomycetaceae;Archaeorhizomyces/

s/Homobasidiomycetes/Agaricomycetes/
s/Floricola/Teichospora/


#Matheny 2005
#s/Cortinariaceae;Inocybe/Inocybaceae;Inocybe/

#Tedersoo 2018
#s/Chytridiomycota;.+Monoblepharidales;/Monoblepharidomycota;Monoblepharidomycetes;Monoblepharidales;/
#s/Chytridiomycota;.+Cladochytriales;/Chytridiomycota;Cladochytridiomycetes;Cladochytriales;/
#s/Chytridiomycota;.+Lobulomycetales;/Chytridiomycota;Lobulomycetes;Lobulomycetales;/
#s/Chytridiomycota;.+Polychytriales;/Chytridiomycota;Polychytriomycetes;Polychytriales;/
#s/Chytridiomycota;.+Rhizophydiales;/Chytridiomycota;Rhizophydiomycetes;Rhizophydiales;/
#s/Chytridiomycota;.+Rhizophlyctis;/Chytridiomycota;Rhizophlyctidomycetes;Rhizophlyctidales;Rhizophlyctidaceae;Rhizophlyctis;/
#s/Chytridiomycota;.+Spizellomycetales;/Chytridiomycota;Spizellomycetes;Spizellomycetales;/
#s/Chytridiomycota;.+Synchytriaceae;/Chytridiomycota;Synchytriomycetes;Synchytriales;Synchytriaceae;/
#s/Chytridiomycota;.+Hyaloraphidium;/Fungi;Chytridiomycota;Hyaloraphidiomycetes;Hyaloraphidiales;Hyaloraphidiales incertae sedis;Hyaloraphidium;/

#s/Fungi;.+Mortierellales;/Fungi;Mortierellomycota;Mortierellomycetes;Mortierellales;/
#s/Fungi;.+Dimargaritales;/Fungi;Kickxellomycota;Dimargaritomycetes;Dimargaritales;/
#s/Fungi;.+Kickxellales;/Fungi;Kickxellomycota;Kickxellomycetes;Kickxellales;/
#s/Fungi;.+Harpellales/Fungi;Kickxellomycota;Harpellomycetes;Harpellales;/
#s/Fungi;.+Endogonales/Fungi;Mucoromycota;Endogonomycetes;Endogonales;/
#s/Fungi;.+Umbelopsis/Fungi;Mucoromycota;Umbelopidomycetes;Umbelopsidales;Umbelopsidaceae;Umbelopsis/
#s/Fungi;.+Mucorales 2;/Fungi;Mucoromycota;Mucoromycetes;Mucorales;/
#s/Fungi;.+Entomophthorales 2;/Fungi;Entomophthoromycota;Entomophthoromycetes;Entomophthorales;/
#s/Fungi;.+Entomophthorales 1;/Fungi;Basidiobolomycota;Basidiobolomycetes;Basidiobolales;/
#s/Fungi;.+Zoopagales;/Fungi;Zoopagomycota;Zoopagomycetes;Zoopagales;/

s/Glomeromycetes;Paraglomerales;/Paraglomeromycetes;Paraglomerales;/

s/Basidiomycota;Entorrhizomycetes;/Entorrhizomycota;Entorrhizomycetes;/
s/Agaricostilbomycetes;Spiculogloeales;/Spiculogloeomycetes;Spiculogloeales;/
s/Exobasidiomycetes;Malasseziales;/Malasseziomycetes;Malasseziales;/

s/Ascomycota incertae sedis;Trichosphaeriales;/Sordariomycetes;Trichosphaeriales;/

# Filling in incertae sedis from Mycobank and GBIF
s/Dothideomycetes incertae sedis;Asterinaceae;/Asterinales;Asterinaceae;/
s/Dothideomycetes incertae sedis;Micropeltidaceae;/Capnodiales;Micropeltidaceae;/
s/Eurotiomycetes incertae sedis;Rhynchostomataceae;/Chaetothyriales;Rhynchostomataceae;/
s/Lecanoromycetes incertae sedis;Thelocarpaceae;/Thelocarpales;Thelocarpaceae;/
s/Leotiomycetes incertae sedis;Myxotrichaceae;/Helotiales;Myxotrichaceae;/
s/Sordariomycetes incertae sedis;Amplistromataceae;/Amplistromatales;Amplistromataceae;/
s/Sordariomycetes incertae sedis;Apiosporaceae;/Xylariales;Apiosporaceae;/
s/Sordariomycetes incertae sedis;Batistiaceae;/Batistiales;Batistiaceae;/
s/Sordariomycetes incertae sedis;Glomerellaceae;/Glomerellales;Glomerellaceae;/

# Matching Unite
s/Eukaryota incertae sedis;Stramenopiles;Labyrinthulomycetes/Stramenopila;Labyrinthulidia;Labyrinthulomycetes/
s/Eukaryota incertae sedis;Stramenopiles;Oomycetes/Stramenopila;Oomycota;Oomycetes/
s/Eukaryota incertae sedis;Stramenopiles;Bacillariophyta/Stramenopila;Ochrophyta;Bacillariophyceae/
s/Bacillariophyta/Bacillariophyceae/g
s/Eukaryota incertae sedis;Stramenopiles;Chrysophyceae/Stramenopila;Ochrophyta;Chrysophyceae/
s/Eukaryota incertae sedis;Stramenopiles;Dictyochophyceae/Stramenopila;Ochrophyta;Dictyochophyceae/
