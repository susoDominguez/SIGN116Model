:- include(auxiliaryFunctions).

recommendation0(R, Label, Strength, Transition) :-
    rdf(R, rdf:type, vocab:'ClinicalRecommendation'),
    label(R, Label),
    rdf(R, vocab:strength, literal(type(_, Strength))),
    rdf(R, vocab:basedOn, BasedOnGraph),
    rdf(_Action, vocab:causes, Transition, BasedOnGraph).

recommendation(R, Label, Strength, CausationBelief) :-
    rdf(R, rdf:type, vocab:'ClinicalRecommendation'),
    label(R, Label),
    rdf(R, vocab:strength, literal(type(_, Strength))),
    rdf(R, vocab:basedOn, CausationBelief).

/** <examples>
?- recommendation(R, Label, Strength, Transition).
*/
    