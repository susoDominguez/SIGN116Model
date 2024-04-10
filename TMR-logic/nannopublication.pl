/* *********************************** */
% ** Assert a Nanopublication
% check how/where to assert the Method
assert_Nanopublication(Label, AgentURI, Method, NanopubURI) :-
    % define URI for the main/head named_graph
    concat_atom([Label, '_head'], HeadID),
    rdf_global_id(data:HeadID, HeadURI),
    % define URI for the nanopublication
    concat_atom([Label, 'nanopub'], NanopubID),
    rdf_global_id(data:NanopubID, NanopubURI),
    rdf_assert(NanopubURI, rdf:type, nanopub:'Nanopublication', HeadURI),
    % define URI for the assertion graph
    concat_atom([Label, '_assertion'], AssertionID),
    rdf_global_id(data:AssertionID, AssertionURI),
    rdf_assert(NanopubURI, nanopub:'hasAssertion', AssertionURI, HeadURI),
    % define URI for the provenance graph
    concat_atom([Label, '_provenance'], ProvID),
    rdf_global_id(data:ProvID, ProvURI),
    rdf_assert(NanopubURI, nanopub:'hasProvenance', ProvURI, HeadURI),
    % define URI for the publicationinfo graph
    concat_atom([Label, '_publicationinfo'], PubInfoID),
    rdf_global_id(data:PubInfoID, PubInfoURI),
    rdf_assert(NanopubURI, rdf:type, nanopub:'Nanopublication', HeadURI),
    rdf_assert(NanopubURI, nanopub:'hasPublicationInfo', PubInfoURI, HeadURI),
    rdf_assert(NanopubURI, prov:'generatedAtTime', PubInfoURI, PubInfoURI), %% Function for timestamp!!!
    rdf_assert(NanopubURI, prov:'wasAttributedTo', AgentURI, PubInfoURI),
    rdf_assert(NanopubURI, prov:'wasGeneratedBy', Method, PubInfoURI).
                                            %sub:dataset_extraction


assertProvSource(NanopubURI, SourceURI) :- % blank node for the text
rdf(NanopubURI, nanopub:'hasProvenance', ProvURI),
rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI),
rdf_assert(AssertionURI, prov:'wasDerivedFrom', SourceURI, ProvURI).

assertProvResourceUsed(NanopubURI, Resource) :-
rdf(NanopubURI, nanopub:'hasProvenance', ProvURI),
rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI),
(   
    rdf(AssertionURI, prov:'wasGeneratedBy', Activity)
;
    rdf_bnode(Activity),
    rdf_assert(Activity, rdf:type, prov:'Activity', ProvURI),
    rdf_assert(AssertionURI, prov:'wasGeneratedBy', Activity, ProvURI)
),
rdf_assert(Activity, prov:'used', Resource, ProvURI).

/**********************************/
deleteNanopublication(NanopubURI) :-
rdf(NanopubURI, nanopub:'hasProvenance', ProvURI, HeadURI),
rdf(NanopubURI, nanopub:'hasAssertion', AssertionURI, HeadURI),
rdf(NanopubURI, nanopub:'hasPublicationInfo', PubInfoURI, HeadURI),
rdf_retractall(_, _, _, PubInfoURI),
rdf_retractall(_, _, _, ProvURI),
rdf_retractall(_, _, _, AssertionURI),
rdf_retractall(NanopubURI, nanopub:'hasProvenance', ProvURI, HeadURI),
rdf_retractall(NanopubURI, nanopub:'hasAssertion', AssertionURI, HeadURI),
rdf_retractall(NanopubURI, nanopub:'hasPublicationInfo', PubInfoURI, HeadURI).

