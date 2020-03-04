# Force the first word of the species name to be the genus.
s/Root;(([^;]+;){7})([^;]+);[^; ]+/Root;\1\3;\3/
# Sebacina vermifera is now Serendipta vermifera
s/Sebacina;Sebacina vermifera/Serendipita;Serendipita vermifera/
# Arcangeliella has been merged with Lactarius
s/Arcangelliella/Lactarius/g
# Some Lactarius have moved to Lactifluus
s/Lactarius;Lactarius acicularis/Lactifluus;Lactifluus acicularis/
s/Lactarius;Lactarius clarkeae/Lactifluus;Lactifluus clarkeae/
s/Lactarius;Lactarius crocatus/Lactifluus;Lactifluus crocatus/
s/Lactarius;Lactarius leae/Lactifluus;Lactifluus leae/
s/Lactarius;Lactarius leonardii/Lactifluus;Lactifluus leonardii/
s/Lactarius;Lactarius petersenii/Lactifluus;Lactifluus petersenii/
s/Lactarius;Lactarius pinguis/Lactifluus;Lactifluus pinguis/
s/Lactarius;Lactarius sp/Russulaceae_Incertae sedis;Russulaceae/
s/Lactarius;Lactarius subgerardii/Lactifluus;Lactifluus subgerardii/
s/Lactarius;Lactarius vitellinus/Lactifluus;Lactifluus vitellinus/
s/Lactarius;Lactarius cf wirrabara/Lactifluus;Lactifluus cf wirrabara/
