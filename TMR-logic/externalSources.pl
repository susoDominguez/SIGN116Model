% Loading/Importing from External Sources

:- rdf_register_prefix(drug, 'http://wifo5-04.informatik.uni-mannheim.de/drugbank/resource/drugs/', [force = true]).
:- rdf_register_prefix(drugBerlim, 'http://www4.wiwiss.fu-berlin.de/drugbank/resource/drugs/', [force = true]).
:- rdf_register_prefix(drugBerlimCat, 'http://www4.wiwiss.fu-berlin.de/drugbank/resource/drugcategory/', [force = true]).
:- rdf_register_prefix(drugcategory, 'http://wifo5-04.informatik.uni-mannheim.de/drugbank/resource/drug_categories/', [force = true]).
:- rdf_register_prefix(drugbank, 'http://wifo5-04.informatik.uni-mannheim.de/drugbank/resource/drugbank/', [force = true]).
:- rdf_register_prefix(sider, 'http://www4.wiwiss.fu-berlin.de/sider/resource/sider/', [force = true]).
:- rdf_register_prefix(dikb, 'http://dbmi-icode-01.dbmi.pitt.edu:2020/vocab/resource/', [force = true]).
:- rdf_register_prefix(ddid, 'http://liddi.stanford.edu/LIDDI:', [force = true]).
:- rdf_register_prefix(ddiv, 'http://liddi.stanford.edu/LIDDI_vocabulary:', [force = true]).
:- rdf_register_prefix(ddir, 'http://liddi.stanford.edu/LIDDI_resource:', [force = true]).
:- rdf_register_prefix(dv, 'http://bio2rdf.org/drugbank_vocabulary:', [force = true]).
:- rdf_register_prefix(drugbankb2r, 'http://bio2rdf.org/drugbank:', [force = true]).

:- include(guidelines).

%*******************************************
%****** Load Data From all sources ************
loadExternalBeliefs :-
    drugbankAssertCausationFromCategory,
    drugbankAssertIncompatibilityBelief,
    sameSituationSider, siderAssertCausationSideEffect,
    dikbAssertIncompatibilityBelief,
    liddiAssertIncompatibilityBelief,
    aersAssertIncompatibilityBelief.

%****** Unload Data From source ************
unloadExternalBeliefs(Source) :-
    rdf_global_id(data:Source, SourceURI),
    forall((
       rdf(AssertionURI, prov:'wasDerivedFrom', SourceURI),
       rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI)
    ), deleteNanopublication(NanopubURI)).

%*******************************************
%****** Importing from Drugbank ************

% old assert causation based on drug category
drugbankAssertCausationFromCategory :-
    rdf_global_id(data:'drugbank', SourceURI),
	forall((
     rdf(DrugCategory, vocab:'hasGroupingCriteria', Trans1),
     rdfs_individual_of(Trans1, vocab:'TransitionType'),
	 rdf(DrugDB, drugbank:'drugCategory', DrugCategoryDB),
	 rdf(DrugCategory, owl:sameAs, DrugCategoryDB),
	 rdf(Act1, vocab:'administrationOf', DrugType),
	 rdf(DrugType, owl:sameAs, DrugDB),
     \+ causes(Act1, Trans1, _, _, SourceURI))
   , (assertCausation2(Act1, Trans1, 'always', SourceURI, NanopubURI),
	 assertProvResourceUsed(NanopubURI, DrugCategoryDB),
	 assertProvResourceUsed(NanopubURI, DrugDB))).
    
% Assert Causation Beliefs and structural grouping 
% for Drug Administrations according to it's category given by drugbank,
% to which is assigned two types of grouping criteria: 
% structural => assert similar grouping criteria to the sub-action
% effect => assert causation
drugbankAssertCausationFromCategoryPlus :-
    forall((
        rdf_global_id(vocab:'DrugType', DrugTypeURI),
     	rdf(DrugCategory, rdf:type, DrugTypeURI),
     	rdf(DrugCategory, vocab:'hasGroupingCriteria', _),
	 	rdf(DrugCategory, owl:sameAs, DrugCategoryDB),
	 	rdf(DrugDB, drugbank:'drugCategory', DrugCategoryDB),
	 	rdf(DrugType, owl:sameAs, DrugDB),
	 	rdf(Act, vocab:'administrationOf', DrugType)
	    %\+ causes(Act, Trans1, _, _, SourceURI))
    ),
    ( 	
    	forall( 
          rdf(DrugCategory, vocab:'hasGroupingCriteria', TypeGrCrit),%then
          (
          (  rdf(TypeGrCrit, rdf:type, vocab:'EventType')
    	    ->  (rdf_global_id(data:'drugbank', SourceURI),           
      		  assertCausation2(Act, TypeGrCrit, 'always', SourceURI))
      		  %assertCausation2(Act, TypeGrCrit, 'always', SourceURI, NanopubURI)),
	          %assertProvResourceUsed(NanopubURI, DrugCategoryDB),
     		  %assertProvResourceUsed(NanopubURI, DrugDB))
		  ; % if the grouping criteria is structural
           % check if there is an event type that has only this grouping criteria
           % and infer subsumption   
		    rdfs_individual_of(TypeGrCrit, vocab:'SituationType'),
		    rdfs_individual_of(SupEventType, vocab:'EventType'),
            rdf(SupEventType, vocab:'hasGroupingCriteria', TypeGrCrit),
            %different(SupEventType,Act),
            SupEventType \= Act,
            forall(rdf(SupEventType, vocab:'hasGroupingCriteria', Type) ,
                   same(Type, TypeGrCrit)) )
    		-> rdf_assert(SupEventType, vocab:'subsumes', Act, 'http://anonymous.org/entailments')
          ; % if there not such event type, than create one as blank node 
          % and infer subsumption
            rdf(TypeGrCrit, rdf:type, vocab:'SituationType')
    		-> (rdf_bnode(SupEventType),
               	rdf_assert(SupEventType, vocab:'hasGroupingCriteria', TypeGrCrit, 'http://anonymous.org/entailments'),
               	rdf_assert(SupEventType, vocab:'subsumes', Act, 'http://anonymous.org/entailments')
               )
          )
        )
    )).
    
% Assert Incompatibility Belief Between Interacting Pair of Drugs
drugbankAssertIncompatibilityBelief :-
	forall((
	 	rdf(Act1, vocab:'administrationOf', DrugT1),
	 	rdf(Act2, vocab:'administrationOf', DrugT2),
	 	different(Act1, Act2),
	 	%same(DrugT1, Drug1),
     	rdf(DrugT1, owl:sameAs, Drug1),
	 	%same(DrugT2, Drug2),
     	rdf(DrugT2, owl:sameAs, Drug2),
     	%to make sure it loads only the data from the drugbank graph
	 	rdf_global_id('file:///home/swish/src/ClioPatria/guidelines2/drugbank_small.nt', G),
	 	rdf(Drug1, drugbank:'interactsWith', Drug2, G:_)           
    ) ,
    ( 	rdf_global_id(data:'drugbank', SourceURI),
      	assertIncompatibility(Act1, Act2, SourceURI, NanopubURI),
        assertProvResourceUsed(NanopubURI, Drug1),
        assertProvResourceUsed(NanopubURI, Drug2))
    ).


%*******************************************
%****** Importing from SIDER ************

% ** when the situtation type has the same UMLScode as sider:SideEffect
% they are infered as the same via owl:sameAs
sameSituationSider :-
	forall((
        rdf(SituationT, vocab:'umlsCode', literal(type(xsd:string, UMLSCode))),
		rdf(SideEffect, sider:'sideEffectId', literal(UMLSCode)),
        \+ rdf(SituationT, owl:sameAs, SideEffect)
	),
    (rdf_assert(SituationT, owl:sameAs, SideEffect, 'http://anonymous.org/data'))).

% Assert Causation Belief for Drug Administration
% For all the DrugTypes that are belived to promote as sideEffects that are same as
% Situations that take part in transitions (for restricting the imported sideEffect)
siderAssertCausationSideEffect :-
    forall((
	 	( rdf(_, vocab:'hasTransformableSituation', Situation)
	 	; rdf(_, vocab:'hasExpectedSituation', Situation)),
	 	%same(Situation, SideEffect),
	 	rdf(Situation, owl:sameAs, SideEffect),
	 	rdf(DrugSider, sider:'sideEffect', SideEffect),
	 	rdf(DrugSider, owl:sameAs, DrugBerlim),
	 	rdf_global_id(drugBerlim:ID, DrugBerlim),
	 	rdf_global_id(drug:ID, DrugDB),
	 	rdf(DrugType, owl:sameAs, DrugDB),
	 	rdfs_individual_of(DrugType, vocab:'DrugType'),
     	rdf(Action, vocab:'administrationOf', DrugType)
     ),
   	 (	assertPartialTransition(Situation, NewTr),
		rdf_global_id(data:'sider', SourceURI),                   
    	assertCausation2(Action, NewTr, 'always', SourceURI, NanopubURI),
        assertProvResourceUsed(NanopubURI, DrugSider),
        assertProvResourceUsed(NanopubURI, SideEffect))).


%*******************************************
%****** Importing from DIKB ************
% Assert Incompatibility Belief Between Interacting Pair of Drugs
dikbAssertIncompatibilityBelief :-
    forall((
     	rdf(Int, dikb:'PrecipitantDrugOfInteraction', Drug1),
	 	rdf(Int, dikb:'ObjectDrugOfInteraction', Drug2),
	 	rdf(Drug1, owl:sameAs, Drug1Berlim),
	 	rdf_global_id(drugBerlim:ID1, Drug1Berlim),
	 	rdf_global_id(drug:ID1, Drug1DB),
	 	rdf(DrugType1, owl:sameAs, Drug1DB),
	 	rdfs_individual_of(DrugType1, vocab:'DrugType'),
     	rdf(Action1, vocab:'administrationOf', DrugType1),
	 	rdf(Drug2, owl:sameAs, Drug2Berlim),
	 	rdf_global_id(drugBerlim:ID2, Drug2Berlim),
	 	rdf_global_id(drug:ID2, Drug2DB),
	 	rdf(DrugType2, owl:sameAs, Drug2DB),
	 	rdfs_individual_of(DrugType2, vocab:'DrugType'),
     	rdf(Action2, vocab:'administrationOf', DrugType2)
     ), 
     ( 	rdf_global_id(data:'dikb', SourceURI),
	   	assertIncompatibility(Action1, Action2, SourceURI, NanopubURI),
        assertProvResourceUsed(NanopubURI, Int),
        assertProvResourceUsed(NanopubURI, Drug1),
        assertProvResourceUsed(NanopubURI, Drug2))).


%*******************************************
%****** Importing from LIDDI ************
% Assert Incompatibility Belief Between Interacting Pair of Drugs
% Future: Assert the undesired effect as causation of the composed action
liddiAssertIncompatibilityBelief :-
	forall((
		rdf(Act1, vocab:'administrationOf', DrugT1),
		rdf(Act2, vocab:'administrationOf', DrugT2),
		different(Act1, Act2),
		%first drug
		rdf(DrugT1, owl:sameAs, Drug1DB),
		rdf_global_id(drug:ID_DB1, Drug1DB),
		rdf_global_id(drugbankb2r:ID_DB1, Durg1DB_B2R),
		rdf(DrugURI1B, ddiv:'mapstodrugbank', Durg1DB_B2R),
		rdf_global_id(ddir:ID1, DrugURI1B),
		rdf_global_id(ddid:ID1, DrugURI1A),
		rdf(DrugURI1A, dv:'ddi-interactor-in', Interaction),
		rdf(DrugURI1B, rdfs:type, ddiv:'drug'),
		%second drug
		rdf(DrugT2, owl:sameAs, Drug2DB),
		rdf_global_id(drug:ID_DB2, Drug2DB),
		rdf_global_id(drugbankb2r:ID_DB2, Durg2DB_B2R),
		rdf(DrugURI2B, ddiv:'mapstodrugbank', Durg2DB_B2R),
		rdf_global_id(ddir:ID2, DrugURI2B),
		rdf_global_id(ddid:ID2, DrugURI2A),
		rdf(DrugURI2A, dv:'ddi-interactor-in', Interaction),
		rdf(DrugURI2B, rdfs:type, ddiv:'drug')
	) ,
    ( 	rdf_global_id(data:'liddi', SourceURI),
      	assertIncompatibility(Act1, Act2, SourceURI, NanopubURI),
        assertProvResourceUsed(NanopubURI, Interaction),
        assertProvResourceUsed(NanopubURI, DrugURI2B),
        assertProvResourceUsed(NanopubURI, DrugURI1B))).
    
    
%*******************************************
%****** Importing from AERS ************
% Assert Incompatibility Belief Between Interacting Many Drugs
aersAssertIncompatibilityBelief :-
	forall(
    (rdf(Report, rdf:type, 'http://aers.data2semantics.org/vocab/Report'),
    % We consider only the reports with involvement from more than one
    % distinct drugbank mapping"
	aggregate_all(count, (distinct([Report,DrugbankBerlimURI], 
      (rdf(Elem, 'http://aers.data2semantics.org/vocab/involved_in', Report),
	  rdf(Elem, 'http://aers.data2semantics.org/vocab/drug', Drug), 
	  rdf(Drug, rdf:type, 'http://aers.data2semantics.org/vocab/Drug'),
      rdf(Drug, skos:'closeMatch', DrugbankBerlimURI),
      rdf_global_id(drugBerlim:DrugbankID, DrugbankBerlimURI)))), Count),
	Count > 1,
    % If all the involved drugs are also part of the described recommendations
    % via the mapping to drugbank
    % ( in order to import only the relevant interactions )
    forall(
      (rdf(Involment, 'http://aers.data2semantics.org/vocab/involved_in', Report),
	  rdf(Involment, 'http://aers.data2semantics.org/vocab/drug', Drug), 
	  rdf(Drug, rdf:type, 'http://aers.data2semantics.org/vocab/Drug')),
      ( rdf(Drug, skos:'closeMatch', DrugbankBerlimURI),
       rdf_global_id(drugBerlim:DrugbankID, DrugbankBerlimURI),
       rdf_global_id(drug:DrugbankID, DrugbankMannheimURI),
       rdf(DrugType, rdf:type, vocab:'DrugType'),
       rdf(DrugType, owl:sameAs, DrugbankMannheimURI)
      ))),
    % Then assert a low-confidence incompatibility belief
    % relating all the actions correspoding to the administration of the 
    % involved drugs
    ( findall((ActionType,Drug), (distinct([ActionType, Drug], 
     (rdf(Involment, 'http://aers.data2semantics.org/vocab/involved_in', Report),
	  rdf(Involment, 'http://aers.data2semantics.org/vocab/drug', Drug), 
	  rdf(Drug, rdf:type, 'http://aers.data2semantics.org/vocab/Drug'),
	  rdf(Drug, skos:'closeMatch', DrugbankBerlimURI),
      rdf_global_id(drugBerlim:DrugbankID, DrugbankBerlimURI),
      rdf_global_id(drug:DrugbankID, DrugbankMannheimURI),
      rdf(DrugType, rdf:type, vocab:'DrugType'),
      rdf(DrugType, owl:sameAs, DrugbankMannheimURI),
      rdf(ActionType, vocab:'administrationOf', DrugType)
 	 ))),EventTypeList),
     rdf_global_id(data:'aers', SourceURI),
     assertIncompatibilityMultiEvents(EventTypeList, SourceURI)
    )).    

