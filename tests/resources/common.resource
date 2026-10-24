*** Settings ***
Library    SeleniumLibrary
Library    RequestsLibrary
Library    Collections
Library    String
Library    OperatingSystem

*** Variables ***
${BASE_URL}         http://localhost
${BROWSER}          chrome
${ADMIN_USER}       admin
${ADMIN_PASSWORD}   Qmn3GytrQm
${SAMPLE_FILE}      ${EXECDIR}${/}tests${/}data${/}sample.txt

${LOGIN_URL}        ${BASE_URL}/authentication/login/
${CABINETS_URL}     ${BASE_URL}/#/cabinets/cabinets/
${EVENTS_URL}       ${BASE_URL}/#/events/events/
${DOCUMENTS_URL}    ${BASE_URL}/#/documents/documents/

${LOC_USERNAME}     id=id_username
${LOC_PASSWORD}     id=id_password

*** Keywords ***
Open Mayan
    Open Browser    ${LOGIN_URL}    ${BROWSER}
    Maximize Browser Window
    Set Selenium Timeout    15s

Login As Admin
    Wait Until Keyword Succeeds    3x    5s    Attempt Login

Attempt Login
    Close All Browsers
    Open Mayan
    Wait Until Element Is Visible    ${LOC_USERNAME}    timeout=20s
    Sleep    2s
    Input Text        ${LOC_USERNAME}    ${ADMIN_USER}
    Input Password    ${LOC_PASSWORD}    ${ADMIN_PASSWORD}
    Press Keys        ${LOC_PASSWORD}    RETURN
    Wait Until Page Contains    Documents    timeout=20s

Unique Name
    [Arguments]    ${prefix}
    ${suffix}=    Generate Random String    5    [LETTERS]
    RETURN    ${prefix}_${suffix}

API Session
    ${auth}=    Create List    ${ADMIN_USER}    ${ADMIN_PASSWORD}
    Create Session    mayan    ${BASE_URL}    auth=${auth}

API Create Cabinet
    [Arguments]    ${label}    ${parent}=${None}
    &{body}=    Create Dictionary    label=${label}    parent=${parent}
    ${resp}=    POST On Session    mayan    /api/v4/cabinets/    json=${body}    expected_status=any
    Log To Console    CREATE CABINET ${resp.status_code} ${resp.text}
    Should Be Equal As Integers    ${resp.status_code}    201
    RETURN    ${resp.json()}[id]

API Upload Document
    [Arguments]    ${path}    ${label}
    &{data}=    Create Dictionary    document_type_id=1    label=${label}
    ${resp}=    POST On Session    mayan    /api/v4/documents/    data=${data}    expected_status=any
    Log To Console    CREATE DOCUMENT ${resp.status_code}
    Should Be Equal As Integers    ${resp.status_code}    201
    ${doc_id}=    Set Variable    ${resp.json()}[id]
    ${files}=    Evaluate    {'file_new': ('${label}.txt', open(r'${path}', 'rb'))}
    &{fdata}=    Create Dictionary    action_name=replace    filename=${label}.txt
    ${fresp}=    POST On Session    mayan    /api/v4/documents/${doc_id}/files/    data=${fdata}    files=${files}    expected_status=any
    Log To Console    ATTACH FILE ${fresp.status_code} ${fresp.text}
    Should Be True    ${fresp.status_code} < 300
    Wait Until Keyword Succeeds    60s    3s    API Document Should Have File    ${doc_id}
    RETURN    ${doc_id}

API Document Should Have File
    [Arguments]    ${doc_id}
    ${r}=    GET On Session    mayan    /api/v4/documents/${doc_id}/files/
    Should Be True    ${r.json()}[count] > 0


API Add Document To Cabinet
    [Arguments]    ${cabinet_id}    ${document_id}
    &{body}=    Create Dictionary    document=${document_id}
    ${resp}=    POST On Session    mayan    /api/v4/cabinets/${cabinet_id}/documents/add/    json=${body}    expected_status=any
    Log To Console    ADD ${resp.status_code} ${resp.text}
    Should Be True    ${resp.status_code} < 300

API Remove Document From Cabinet
    [Arguments]    ${cabinet_id}    ${document_id}
    &{body}=    Create Dictionary    document=${document_id}
    ${resp}=    POST On Session    mayan    /api/v4/cabinets/${cabinet_id}/documents/remove/    json=${body}    expected_status=any
    Log To Console    REMOVE ${resp.status_code} ${resp.text}
    Should Be True    ${resp.status_code} < 300