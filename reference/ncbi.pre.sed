
# Attine ant cultivars are, annoyingly, listed as the genus of their ant, not the fungus.
# Classification is a bit unclear in Leucocoprinus/Leucoagaricus
# Choose Leucocoprinus as the most likely option
s/Agaricaceae;(Atta|(Cypho|Serico|Trachy)myrmex|Mycet(arotes|ophylax|osoritis)|Mycocepurus|Myrmicocrypta)/Agaricaceae;Leucocoprinus/

# Higher taxa matching different genera
s/Gastropoda;Euthyneura/Gastropoda/
s/Ichthyostraca;Branciura/Ichthyostraca/
s/Bilateria;Gnathifera/Bilateria/
s/Archaeplastida;Coccomyxa/Archaeplastida;Trebouxiophyceae;Coccomyxa/
s/Echinoidea;Echinacea/Echinoidea/
s/Polypodiopsida;Polypodiidae/Polypodiopsida/

# Matching Unite
s/Stramenopiles/Stramenopila/
s/Bacillariophyta/Bacillariophyceae/
