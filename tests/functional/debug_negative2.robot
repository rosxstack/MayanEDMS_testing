*** Settings ***
Resource          ../resources/common.resource
Suite Setup       API Session

*** Test Cases ***
Probe Control Reparent
    ${a}=    Unique Name    PROBE_A
    ${b}=    Unique Name    PROBE_B
    ${aid}=    API Create Cabinet    ${a}
    ${bid}=    API Create Cabinet    ${b}
    &{body}=    Create Dictionary    parent=${aid}
    ${r}=    PATCH On Session    mayan    /api/v4/cabinets/${bid}/    json=${body}    expected_status=any
    Log To Console    CONTROL-REPARENT ${r.status_code}

Probe Cycle State
    ${p}=    Unique Name    PROBE_P
    ${c}=    Unique Name    PROBE_C
    ${pid}=    API Create Cabinet    ${p}
    ${cid}=    API Create Cabinet    ${c}    ${pid}
    &{body}=    Create Dictionary    parent=${cid}
    ${r}=    PATCH On Session    mayan    /api/v4/cabinets/${pid}/    json=${body}    expected_status=any
    Log To Console    CYCLE ${r.status_code}
    ${gp}=    GET On Session    mayan    /api/v4/cabinets/${pid}/
    ${gc}=    GET On Session    mayan    /api/v4/cabinets/${cid}/
    Log To Console    STATE parent_of_P=${gp.json()}[parent_id] parent_of_C=${gc.json()}[parent_id]

Probe Self Parent
    ${p}=    Unique Name    PROBE_S
    ${pid}=    API Create Cabinet    ${p}
    &{body}=    Create Dictionary    parent=${pid}
    ${r}=    PATCH On Session    mayan    /api/v4/cabinets/${pid}/    json=${body}    expected_status=any
    Log To Console    SELF-PARENT ${r.status_code}

Probe Anonymous API
    Create Session    anon    ${BASE_URL}
    ${r}=    GET On Session    anon    /api/v4/cabinets/    expected_status=any
    Log To Console    ANON ${r.status_code}

Probe Wrong Password API
    ${auth}=    Create List    admin    definitely_wrong
    Create Session    bad    ${BASE_URL}    auth=${auth}
    ${r}=    GET On Session    bad    /api/v4/cabinets/    expected_status=any
    Log To Console    BADPASS ${r.status_code}

Probe Add Missing Document
    ${p}=    Unique Name    PROBE_M
    ${pid}=    API Create Cabinet    ${p}
    &{body}=    Create Dictionary    document=999999
    ${r}=    POST On Session    mayan    /api/v4/cabinets/${pid}/documents/add/    json=${body}    expected_status=any
    Log To Console    ADD-MISSING ${r.status_code}


Probe Anonymous Body
    Create Session    anon2    ${BASE_URL}
    ${r}=    GET On Session    anon2    /api/v4/cabinets/    expected_status=any
    ${s}=    Evaluate    $r.text[:150]
    Log To Console    ANON-CABINETS ${r.status_code} ${s}
    ${r2}=    GET On Session    anon2    /api/v4/documents/    expected_status=any
    ${s2}=    Evaluate    $r2.text[:150]
    Log To Console    ANON-DOCUMENTS ${r2.status_code} ${s2}
    ${r3}=    GET On Session    anon2    /api/v4/cabinets/2/    expected_status=any
    Log To Console    ANON-CABINET2 ${r3.status_code}