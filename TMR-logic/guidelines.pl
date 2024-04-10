/*

This code provides the SWI-Prolog implementation of the rules described in 
the paper named:
"..."
 
It provides as data the three guidelines provided as case study in that paper:
Osteoarthritis (OA), Diabetes (DB), and Hypertension (HT)

*/

:- rdf_prefix(data, 'http://anonymous.org/data/').
:- rdf_prefix(vocab, 'http://anonymous.org/vocab/').
:- rdf_prefix(vocab4i, 'http://anonymous.org/vocab4i/').
:- rdf_prefix(oa, 'http,//www.w3.org/ns/oa#').
:- rdf_prefix(prov, 'http://www.w3.org/ns/prov#').
:- rdf_prefix(nanopub, 'http://www.nanopub.org/nschema#').

:- include(auxiliaryFunctions).
:- include(nanopublication).

/* *********************************** */
%  EVENT_TYPE-BASED RULES
/* *********************************** */
% 
inverseTo(TransitionT1, TransitionT2) :-
	rdfs_individual_of(TransitionT1, vocab:'TransitionType'),
	rdfs_individual_of(TransitionT2, vocab:'TransitionType'),
    rdf(TransitionT1, vocab:'hasTransformableSituation', S1),
    rdf(TransitionT1, vocab:'hasExpectedSituation', S2),
    rdf(TransitionT2, vocab:'hasTransformableSituation', S2),
    rdf(TransitionT2, vocab:'hasExpectedSituation', S1),
    different(TransitionT1, TransitionT2).

/* *********************************** */
% relatedTypes(Type1, Type2)    
% check if two types are the same or subsuming one another
relatedTypes(Type1, Type2) :-
    (   same(Type1, Type2) ->  true
    ;
        subsumes(Type1, Type2) ->  true
    ;   
        subsumes(Type2, Type1) ->  true
    ;   
        (subsumes(Type1, Type3),
         same(Type3, Type2) )
    ).

% makes subsumption to hold whenever there is a positive cbelief
% improve with selection of relieable sources
subsumes(SType, Type) :-
    %rdf_global_id(SType1, SType),
    %rdf_global_id(Type1, Type),
    % SuperType subsumes Type if
    (   SType \= Type,
        % the Type is reachable via subsumes relationship
    	rdf_reachable(SType, vocab:'subsumes', Type) -> true
    ;   % or it satisfies the grouping criterias of SType
    	% of which at least one is effect
    	subsumesDueToEffect(SType, Type, _)
    	% subsumesViaGroupingCriterias(SType, Type, _)
    ).

propagGroupingCriteriaDrugToEventType :-
   forall((
      rdf(DrugType, vocab:'hasGroupingCriteria', Type),
      rdf(EventType, vocab:'administrationOf', DrugType)
      ),
	  rdf_assert(EventType, vocab:'hasGroupingCriteria', Type, 'http://anonymous.org/data')
      ).

subsumesDueToEffect(EventType1, EventType2, CBelief) :-
    rdf_global_id(EventType1, EvType1URI),
    rdf_global_id(EventType2, EvType2URI),
	rdfs_individual_of(EvType1URI, vocab:'EventType'),
	rdfs_individual_of(EvType2URI, vocab:'EventType'),
    rdf(EvType1URI, vocab:'hasGroupingCriteria', TrType),
    causes(EvType2URI, TrType, 'always', CBelief),
    EventType1 \= EventType2,
    \+ rdf(EvType1URI, owl:sameAs, EvType2URI),
    \+ rdf(EvType2URI, owl:sameAs, EvType1URI).
    %different(EventType1,EventType2).

subsumesViaGroupingCriterias(EventType1, EventType2, CBelief) :-
	rdfs_individual_of(EventType1, vocab:'EventType'),
	rdfs_individual_of(EventType2, vocab:'EventType'),
    rdf(EventType1, vocab:'hasGroupingCriteria', _),
    different(EventType1, EventType2),
    forall(
        % The grouping criterias can be both a promoted Effect or 
        % a structural super-type (e.g. administration of non-steroidal)
        rdf(EventType1, vocab:'hasGroupingCriteria', Type),
        (causes(EventType2, Type, 'always', CBelief)
        ;(rdf(CatType, vocab:'hasGroupingCriteria', Type),
          rdf_reachable(CatType, vocab:'subsumes', EventType2))
        )).
    %EventType1 \= EventType2,
    %\+ rdf(EventType1, owl:sameAs, EventType2),
    %\+ rdf(EventType2, owl:sameAs, EventType1).
    
/* *********************************** */
%  BELIEF-BASED RULES
/* *********************************** */

causes(EventT1, EventT2, Frequency, CBelief) :-
    rdfs_individual_of(CBelief, vocab:'CausationBelief'),
    rdf(CBelief, vocab:'frequency', literal(type(xsd:string, Frequency)), CBelief),
    rdf(EventT1, vocab:'causes', EventT2, CBelief).
causes(EventT1, EventT2, Frequency, CBelief, Source) :-
    causes(EventT1, EventT2, Frequency, CBelief),
    rdf(CBelief, prov:'wasDerivedFrom', Source).

similarTo(CBelief1, CBelief2) :-
    rdfs_individual_of(CBelief1, vocab:'CausationBelief'),
    rdfs_individual_of(CBelief2, vocab:'CausationBelief'),
    causes(EventT1, EventT3, Frequency, CBelief1),
    causes(EventT2, EventT3, Frequency, CBelief2),
    different(EventT1, EventT2).

incompatibleWith(EventT1, EventT2, IBelief) :-
    rdfs_individual_of(EventT1, vocab:'EventType'),
    rdfs_individual_of(EventT2, vocab:'EventType'),
    rdf(EventT1, vocab:'incompatibleWith', EventT2, IBelief).


/* *********************************** */
%  NORM-BASED RULES
/* *********************************** */

regulates(Reg, Norm, ActionT, Strength, CBelief) :-
    rdfs_individual_of(Norm, vocab:'Norm'),
    rdf(Norm, vocab:'partOf', Reg, Norm), 
    rdf(Norm, vocab:'strength', literal(type(xsd:string, Strength)), Norm),
    rdf(Norm, vocab:'basedOn', CBelief, Norm),
    rdf(Norm, vocab:'aboutExecutionOf', ActionT, Norm).
    

/* *********************************** */
%  ASSERTIONS
/* *********************************** */


/* *********************************** */
% ** Assert a causation belief
assertCausation2(CauseTURI, EffectTURI, Frequency, SourceURI) :-
	assertCausation2(CauseTURI, EffectTURI, Frequency, SourceURI, _).
    
assertCausation2(CauseTURI, EffectTURI, Frequency, SourceURI, NanopubURI) :-
    (   %check if causation is already asserted for the source
    	rdf(CauseTURI, vocab:'causes', EffectTURI, BeliefURI:_), 
		rdf(BeliefURI, vocab:'frequency', literal(type(xsd:string, Frequency))),
		rdf(BeliefURI, prov:'wasDerivedFrom', SourceURI),
	    rdfs_individual_of(BeliefURI, vocab:'CausationBelief')  ->   true
    ;   
        % composing new URI for nanopublication
        rdf_global_id(data:ID1, CauseTURI),
        rdf_global_id(data:ID2, EffectTURI),
        rdf_global_id(data:SourceID, SourceURI),
        concat_atom([SourceID, 'CB', ID1, ID2, Frequency], LabelID),
        rdf_global_id(data:'PrologRBS', AgentURI),
        % creating the Nanopublication
        assert_Nanopublication(LabelID, AgentURI, 'dataset_extraction', NanopubURI),
        % asserting the causation belief
    	rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI),
        rdf_assert(AssertionURI, rdf:type, vocab:'CausationBelief', AssertionURI),
        rdf_assert(CauseTURI, vocab:'causes', EffectTURI, AssertionURI),
        rdf_assert(AssertionURI, vocab:'frequency', literal(type(xsd:string, Frequency)), AssertionURI),
        % asserting the provenance
        assertProvSource(NanopubURI, SourceURI)
    ).

/* *********************************** */
% ** Assert an incompatibility belief
assertIncompatibility(EventTURI1, EventTURI2, SourceURI) :-
	assertIncompatibility(EventTURI1, EventTURI2, SourceURI, _).

assertIncompatibility(EventTURI1, EventTURI2, SourceURI, NanopubURI) :-
    (   %check if incompatibility is already asserted for the source
    	(rdf(EventTURI1, vocab:'incompatibleWith', EventTURI2, Belief:_);
         rdf(EventTURI2, vocab:'incompatibleWith', EventTURI1, Belief:_)),
		rdf(Belief, prov:'wasDerivedFrom', SourceURI),
        rdf_global_id(vocab:'IncompatibilityBelief', IBType),
   		instanceOf(Belief, IBType)  ->   true
    ;   
        % composing new URI for belief
        rdf_global_id(data:ID1, EventTURI1),
        rdf_global_id(data:ID2, EventTURI2),
        rdf_global_id(data:SourceID, SourceURI),
        concat_atom([SourceID, 'IB', ID1, ID2], LabelID),
        rdf_global_id(data:'PrologRBS', AgentURI),
        % creating the Nanopublication
        assert_Nanopublication(LabelID, AgentURI, 'dataset_extraction', NanopubURI),
        % asserting the incompatibility belief
    	rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI),
        rdf_assert(AssertionURI, rdf:type, vocab:'IncompatibilityBelief', AssertionURI),
        rdf_assert(EventTURI1, vocab:'incompatibleWith', EventTURI2, AssertionURI),
        rdf_assert(AssertionURI, vocab:'isAbout', EventTURI1, AssertionURI),
        rdf_assert(AssertionURI, vocab:'isAbout', EventTURI2, AssertionURI),
        % asserting the provenance
        assertProvSource(NanopubURI, SourceURI)
    ).

assertIncompatibilityMultiEvents(EventTypeListURI, SourceURI) :-
	(   rdf(Belief, prov:'wasDerivedFrom', SourceURI),
		rdfs_individual_of(Belief, vocab:'IncompatibilityBelief'),
    	foreach(member((EventTypeURI,_), EventTypeListURI),
			rdf(Belief, vocab:'isAbout', EventTypeURI, Belief:_)) -> true
    ; 
    	% >>> make a name for the belief: compose all events' names??
        rdf_global_id(data:SourceID, SourceURI),
        random_between(0,1000000,R),
        concat_atom([SourceID, 'IB', R], LabelID),
        rdf_global_id(data:'PrologRBS', AgentURI),
        % creating the Nanopublication
        assert_Nanopublication(LabelID, AgentURI, 'dataset_extraction', NanopubURI),
        % asserting the incompatibility belief
    	rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI),
        rdf_assert(AssertionURI, rdf:type, vocab:'IncompatibilityBelief', AssertionURI),
    	foreach(member((EventTypeURI,_), EventTypeListURI),
                rdf_assert(AssertionURI, vocab:'isAbout', EventTypeURI, AssertionURI)),        % asserting the provenance
    	foreach(member((_,ExtResource), EventTypeListURI),
                assertProvResourceUsed(NanopubURI, ExtResource)),
        assertProvSource(NanopubURI, SourceURI)
    ).

%% meant for assertion the causation from interaction in LIDDI
updateIncompatibility2(EventTURI1, EventTURI2, SituationURI, SourceURI) :-
    (   %check if incompatibility is already asserted for the source
    	(rdf(EventTURI1, vocab:'incompatibleWith', EventTURI2, Belief:_);
         rdf(EventTURI2, vocab:'incompatibleWith', EventTURI1, Belief:_)),
		rdf(Belief, prov:'wasDerivedFrom', SourceURI),
   		rdfs_individual_of(Belief, vocab:'IncompatibilityBelief')  ->   true
    ;   
        % composing new URI for belief
        rdf_global_id(data:ID1, EventTURI1),
        rdf_global_id(data:ID2, EventTURI2),
        rdf_global_id(data:SourceID, SourceURI),
        concat_atom([SourceID, 'IB', ID1, ID2], LabelID),
        rdf_global_id(data:'PrologRBS', AgentURI),
        % creating the Nanopublication
        assert_Nanopublication(LabelID, AgentURI, 'dataset_extraction', NanopubURI),
        % asserting the incompatibility belief
    	rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI),
        rdf_assert(AssertionURI, rdf:type, vocab:'IncompatibilityBelief', AssertionURI),
        rdf_assert(EventTURI1, vocab:'incompatibleWith', EventTURI2, AssertionURI),
        % asserting the provenance
        assertProvSource(NanopubURI, SourceURI),
        % asserting the causation for the incompatibility belief
        % if the composed action does not exist, create it
        ( ( rdf(EventTURI1, vocab:'partOf', ComposedActionURI),
            rdf(EventTURI2, vocab:'partOf', ComposedActionURI)
          );
          ( concat_atom([ID1, ID2], ComposedActionID),
	        rdf_global_id(data:ComposedActionID, ComposedActionURI),
            rdf_assert(EventTURI1, vocab:'partOf', ComposedActionURI),
          	rdf_assert(EventTURI2, vocab:'partOf', ComposedActionURI)
          )
        ),
        % assert a transition that has post situation SituationURI           
        rdf_global_id(data:SituationID, SituationURI),
       	concat_atom(['TrIB', ID1, ID2, SituationID, SourceID], EffectID),
        rdf_global_id(data:EffectID, EffectTURI),
    	% assert a causation 
        rdf_assert(AssertionURI, rdf:type, vocab:'CausationBelief', AssertionURI),
        rdf_assert(ComposedActionURI, vocab:'causes', EffectTURI, AssertionURI),
        rdf_assert(EffectTURI, vocab:'hasExpectedSituation', SituationURI, AssertionURI)    	 
    ).


assertTransition(TransformableSituation, ExpectedSituation, Transition) :-
    (   rdf(Transition, vocab:'hasTransformableSituation', TransformableSituation),
		rdf(Transition, vocab:'hasExpectedSituation', ExpectedSituation) ->   true
    ;   
        % composing new URI for transition
		(rdf_global_id(data:ID1, TransformableSituation),
        rdf_global_id(data:ID2, ExpectedSituation),
        concat_atom(['Tr', ID1, ID2], NewID),
        rdf_global_id(data:NewID, Transition),
        % asserting the transition
        rdf_assert(Transition, rdf:type, vocab:'TransitionType'),
        rdf_assert(Transition, vocab:'hasTransformableSituation', TransformableSituation),
        rdf_assert(Transition, vocab:'hasExpectedSituation', ExpectedSituation))
    ).

assertPartialTransition(ExpectedSituation, Transition) :-
    (   % composing new URI for transition
		rdf_global_id(data:ID2, ExpectedSituation),
        concat_atom(['TrNone', ID2], NewID),
        rdf_global_id(data:NewID, Transition),
        % asserting the transition
        rdf_assert(Transition, rdf:type, vocab:'TransitionType'),
        rdf_assert(Transition, vocab:'hasExpectedSituation', ExpectedSituation)
    ).

%propagCausation :-
%:- forall(
%      rdf(EventType, vocab:'hasGroupingCriteria', TrType),
%	  assertCausation(EventType, TrType, 'always', 'None')).
