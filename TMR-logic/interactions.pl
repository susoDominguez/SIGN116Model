:- use_module(library(semweb/rdfs)).
:- include(auxiliaryFunctions).

interaction(I, Label, Elements) :-
    distinct(Label-Elements, interaction_(I, Label, Elements)).

interaction_(I, Label, Elements) :-
    rdfs_individual_of(I, vocab4i:'Interaction'),
    rdf(I, rdf:type, Class),
    label(Class, Label),
    findall(E, interaction_element(I, E), Elements0),
    sort(Elements0, Elements).

interaction_element(I, E) :-
    ( rdf_reachable(I, owl:sameAs, I2)
    ; rdf_reachable(I2, owl:sameAs, I)),  
    rdf(I2, vocab4i:relates, E).