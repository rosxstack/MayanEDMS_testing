*** Settings ***
Resource          ../resources/common.resource
Suite Setup       API Session

*** Test Cases ***
Probe Duplicate Cabinet
    ${label}=    Unique Name    PROBE_Dup
    ${id1}=    API Create Cabinet    ${label}
    &{body}=    Create Dictionary    label=${label}    parent=${None}
    ${r}=    POST On Session    mayan    /api/v4/cabinets/    json=${body}    expected_status=any
    Log To Console    DUPLICATE ${r.status_code} ${r.text}

Probe Cabinet Into Own Child
    ${p}=    Unique Name    PROBE_P
    ${c}=    Unique Name    PROBE_C
    ${pid}=    API Create Cabinet    ${p}
    ${cid}=    API Create Cabinet    ${c}    ${pid}
    &{body}=    Create Dictionary    parent=${cid}
    ${r}=    PATCH On Session    mayan    /api/v4/cabinets/${pid}/    json=${body}    expected_status=any
    Log To Console    SELF-NEST ${r.status_code} ${r.text}

Probe Delete Document
    ${label}=    Unique Name    PROBE_Doc
    ${doc}=    API Upload Document    ${SAMPLE_FILE}    ${label}
    ${r}=    DELETE On Session    mayan    /api/v4/documents/${doc}/    expected_status=any
    Log To Console    DELETE ${r.status_code} ${r.text}
    ${g}=    GET On Session    mayan    /api/v4/documents/${doc}/    expected_status=any
    Log To Console    GET AFTER DELETE ${g.status_code}