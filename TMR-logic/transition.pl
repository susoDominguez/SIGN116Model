:- include(auxiliaryFunctions).
:- use_module(library(semweb/rdfs)).
:- use_module(library(dcg/basics)).

transition0(T, TropeType, BeforeValue, ActionL, AfterValue) :-
    rdf(T, vocab:hasExpectedSituation, After),
    label(After, AfterL),
    tropetype_value(AfterL, TropeType, AfterValue),
    (   rdf(T, vocab:hasTransformableSituation, Before)
    ->  label(Before, BeforeL),
        tropetype_value(BeforeL, TropeType, BeforeValue)
    ;   BeforeValue = '?'
    ),
    rdf(Action, vocab:causes, T),
    label(Action, ActionL).

transition(CausationBelief, TropeType, BeforeValue, ActionL, AfterValue) :-
    rdfs_individual_of(CausationBelief, vocab:'CausationBelief'),
    rdf(Action, vocab:'causes', Transition, CausationBelief),
    label(Action, ActionL),
    rdf(Transition, vocab:'hasExpectedSituation', After),
    label(After, AfterL),
    tropetype_value(AfterL, TropeType, AfterValue),
    (   rdf(Transition, vocab:'hasTransformableSituation', Before)
    ->  label(Before, BeforeL),
        tropetype_value(BeforeL, TropeType, BeforeValue)
    ;   BeforeValue = '?'
    ).

transition(IB, 'unknown', '?', ActionL, 'undesired state') :-
    rdfs_individual_of(IB, vocab:'IncompatibilityBelief'),
	findall(Label,(rdf(IB, vocab:isAbout, Action),
    				( rdf(Action, vocab:administrationOf, Drug)
					  -> label(Drug, Label)
					; label(Action, Label))), 
            		ActionLabelsList),
    % assuming the example is only about drug administration
    % we make the label shorter using 'Administer' only once
    concat_atom(ActionLabelsList, ' + ', ActionL0),
    concat_atom(['Administer ', ActionL0], ActionL).

tropetype_value(Label, TropeType, Value) :-
    atom_codes(Label, Codes),
    phrase(tropetype_value(TropeType, Value), Codes).

tropetype_value(TropeType, Value) -->
    string(TTCodes), " is ", string(VCodes), eos, !,
    { atom_codes(TropeType, TTCodes),
      atom_codes(Value, VCodes)
    }.
tropetype_value('Pain', 'yes') -->
    "Patient has Pain", !.
tropetype_value('Pain', 'no') -->
    "Patient has no Pain", !.
tropetype_value('TropeType', 'Value') -->
    string(_).


