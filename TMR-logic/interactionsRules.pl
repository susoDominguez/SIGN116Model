/* *********************************** */
%  INTERACTION-BASED RULES
/* *********************************** */

:- include(guidelines).

% Check if an interaction exist among two norms
interacts(IntType, Norm1, Norm2, Interaction) :-
   rdf(Interaction, vocab4i:'relates', Norm1),
   rdf(Interaction, vocab4i:'relates', Norm2),
   rdfs_individual_of(Interaction, IntTypeURI),
   rdf_global_id(vocab4i:IntType, IntTypeURI),
   different(Norm1, Norm2).


/* *********************************** */
% ** Assert an interaction of a certain type between the two recommendations
% just in case the interaction does not already exist
existsInteraction(IntType, Norm1, Norm2) :-
    (   interacts(IntType, Norm1, Norm2, _) -> true
    ;
        % composing new URI for interaction
        rdf_global_id(data:IDNorm1, Norm1),
        rdf_global_id(data:IDNorm2, Norm2),
        concat_atom([IntType, IDNorm1, IDNorm2], NewID),
        rdf_global_id(data:NewID, NewURI),
        % asserting the interaction
        rdf_global_id(vocab4i:IntType, IntTypeURI),
        rdf_assert(NewURI, rdf:type, IntTypeURI, my_entailments),
        rdf_assert(NewURI, vocab4i:'relates', Norm1, my_entailments),
        rdf_assert(NewURI, vocab4i:'relates', Norm2, my_entailments)
    ).

existsInteraction(IntType, Resource1, Resource2, Resource3) :-
    (   %check if the interaction already exists
    	rdf(Interaction, vocab4i:'relates', Resource1),
		rdf(Interaction, vocab4i:'relates', Resource1),
		rdf(Interaction, vocab4i:'relates', Resource3),
        rdf_global_id(vocab4i:IntType, IntTypeURI),
   		rdfs_individual_of(Interaction, IntTypeURI),
   		different(Resource1, Resource2),  
   		different(Resource1, Resource3) , 
   		different(Resource2, Resource3)  ->   true
    ;
        % composing new URI for interaction
        rdf_global_id(data:ID1, Resource1),
        rdf_global_id(data:ID2, Resource2),
        rdf_global_id(data:ID3, Resource3),
        concat_atom([IntType, ID1, ID2, ID3], NewID),
        rdf_global_id(data:NewID, NewURI),
        % asserting the interaction
        rdf_global_id(vocab4i:IntType, IntTypeURI),
        rdf_assert(NewURI, rdf:type, IntTypeURI, my_entailments),
        rdf_assert(NewURI, vocab4i:'relates', Resource1, my_entailments),
        rdf_assert(NewURI, vocab4i:'relates', Resource2, my_entailments),
        rdf_assert(NewURI, vocab4i:'relates', Resource3, my_entailments)
    ).

existsInteractionList(IntType, ResourceList) :-
    (   %check if the interaction already exists
    	rdf_global_id(vocab4i:IntType, IntTypeURI),
   		rdfs_individual_of(Interaction, IntTypeURI),
    	foreach(member(Resource, ResourceList),
			rdf(Interaction, vocab4i:'relates', Resource)) -> true
	    ;
        % composing new random URI for interaction
        random_between(0,1000000,R),
        concat_atom([IntType, R], NewID),
        rdf_global_id(data:NewID, NewURI),
        % asserting the interaction
        rdf_global_id(vocab4i:IntType, IntTypeURI),
        rdf_assert(NewURI, rdf:type, IntTypeURI, my_entailments),
        foreach(member(Resource, ResourceList),
			rdf_assert(NewURI, vocab4i:'relates', Resource, my_entailments))
    ).


/* *********************************** */
% ** infer the internal interactions for all the norms in a regulation
inferInternalInteractions :-
    detectContradiction,
    detectRepetition,
    detectAlternativeActions,
    detectReparableTransition.

% check Contradiction
detectContradiction :-
    forall((
     	regulates(Reg, Norm1, Act1, 'should', CB1),               
     	regulates(Reg, Norm2, Act2, Strength, CB2),
     	causes(Act1, Tr1, 'always', CB1),
     	causes(Act2, Tr2, 'always', CB2),
     	( (Strength = 'should-not',
     	   relatedTypes(Act1,Act2))
     	; (Strength = 'should-not',
     	   different(Act1,Act2),
     	   same(Tr1,Tr2))
     	; (Strength = 'should',
		   different(Act1,Act2),
     	   inverseTo(Tr1,Tr2))  ),
     	different(Norm1,Norm2) 
     ),
     (existsInteraction('Contradiction', Norm1, Norm2))).

% check RepeatedAction
detectRepetition :-
    forall((
     	regulates(Reg, Norm1, Act1, 'should', _),               
     	regulates(Reg, Norm2, Act2, 'should', _),
     	relatedTypes(Act1,Act2),
     	different(Norm1,Norm2) 
    ),
    (existsInteraction('RepeatedAction',Norm1, Norm2))),

    % accumulate RepeatedAction
    forall( (
        interacts('RepeatedAction', Norm1, Norm2, I1),
     	interacts('RepeatedAction', Norm2, Norm3, I2), 
     	different(Norm1,Norm3), different(I1, I2) 
     ),
     rdf_assert(I1, owl:sameAs, I2, my_entailments) ).

detectAlternativeActions :-
    forall((
     	regulates(Reg, Norm1, _, 'should', CB1),               
     	regulates(Reg, Norm2, _, 'should', CB2),
     	similarTo(CB1, CB2) %includes diff(a1, a2) and diff(n1, n2).
     ),
     (existsInteraction('AlternativeActions', Norm1, Norm2))),

    % accumulate AlternativeActions
    forall( (
        interacts('AlternativeActions', Norm1, Norm2, I1),
     	interacts('AlternativeActions', Norm2, Norm3, I2), 
     	different(Norm1,Norm3), different(I1, I2)
     ),
     rdf_assert(I1, owl:sameAs, I2, my_entailments) ).

detectReparableTransition :-
    forall((
	    regulates(Reg, Norm1, Act1, 'should-not', CB1),               
	    regulates(Reg, Norm2, Act2, 'should', CB2),
	    causes(Act1, Tr1, 'always', CB1),
     	causes(Act2, Tr2, 'always', CB2),
	 	inverseTo(Tr1, Tr2), 
     	different(Act1, Act2),               
    	different(Norm1, Norm2) 
    ),
    (existsInteraction('ReparableTransition', Norm1, Norm2))).

/* *********************************** */
% ** infer the internal interactions for all the norms in a regulation
inferExternalInteractions :-
	detectExternalAlternativeAction,
    detectExternalIncompatibleActions,
    detectExternalIncompatibleEffect.

detectExternalAlternativeAction :-
    forall((
     	regulates(Reg, Norm1, _, 'should', CB1),       
	 	%interacts('Contradiction', Norm1, _, _),           
     	causes(Act2, _, 'always', CB2),
	 	similarTo(CB1, CB2), 
     	%different(Act1, Act2),
     	\+ (regulates(Reg, _, Act2, 'should', CB2))
     ),
     (existsInteraction('ExternalAlternativeAction', Norm1, CB2))),

    % accumulate ExternalAlternativeAction
    forall((
     	interacts('ExternalAlternativeAction', Norm1, CB, I1),
     	interacts('ExternalAlternativeAction', Norm2, CB, I2), 
        regulates(Reg, Norm1, _, _, _),
        regulates(Reg, Norm2, _, _, _),
        rdfs_individual_of(CB, vocab:'CausationBelief'), 
     	different(Norm1,Norm2), different(I1, I2)
     ),
     (rdf_assert(I1, owl:sameAs, I2, my_entailments) )).
    

    % check ExternalIncompatibleActions
    %forall((
    % 	regulates(Reg, Norm1, Act1, 'should', CB1),               
    % 	regulates(Reg, Norm2, Act2, 'should', CB2),               
    % 	different(Act1, Act2),
    % 	relatedTypes(Act1, Act3),
    % 	relatedTypes(Act2, Act4),
	% 	incompatibleWith(Act3, Act4, IBelief)
    % ),
    % %\+ (regulates(Reg, Norm2, Act2, 'should', CB2))),
    % (existsInteraction('ExternalIncompatibleActions', Norm1, Norm2, IBelief))),

detectExternalIncompatibleActions :- % for multi-actions
    forall((
        rdfs_individual_of(IncBelief, vocab:'IncompatibilityBelief'),
        rdfs_individual_of(Reg, vocab:'Regulation'),
        forall( rdf(IncBelief, vocab:'isAbout', Action),
                (regulates(Reg, _, Action, 'should', _)
                 ;   
                regulates(Reg, _, RelAction, 'should', _),
                relatedTypes(Action, RelAction)))
     ),
     ( findall(Norm, (distinct([Norm], 
        (rdf(IncBelief, vocab:'isAbout', Action),
         (regulates(Reg, Norm, Action, 'should', _)
         ;   
         regulates(Reg, Norm, RelAction, 'should', _),
         relatedTypes(Action, RelAction))
 	    ))),NormsList),
       append(NormsList, [IncBelief], ResourceList),
       %>>> infer interaction among n recommendations
       existsInteractionList('ExternalIncompatibleActions', ResourceList)
     )).
           
detectExternalIncompatibleEffect :-
    forall((
	     regulates(Reg, Norm1, Act1, Strength, CB1),
	     causes(Act1, Tr1, 'always', CB1),
	     ((Strength = 'should',
	       rdf(Tr1, vocab:'hasTransformableSituation', St1))
	     ; (Strength = 'should-not',
	       rdf(Tr1, vocab:'hasExpectedSituation', St1))),
	     causes(Act, Tr, 'always', CB),
	     different(Act, Act1),               
	     rdf(Tr, vocab:'hasExpectedSituation', St1),
	     regulates(Reg, Norm2, Act2, 'should', CB2), 
	     relatedTypes(Act, Act2),
     	different(CB2, CB)
     ),
     (existsInteraction('ExternalIncompatibleEffects', Norm1, Norm2, CB))).

