*** Settings ***
Documentation     F04 - Document Organisation (Mayan cabinets = folders).
...               Author: Roshan Khati.
...               Tests 01-03 are the acceptance tests (positive path); tests 04-06 are
...               negative tests that check Mayan rejects invalid requests.
Resource          ../resources/common.resource
Suite Setup       Setup F04
Suite Teardown    Close All Browsers
Test Tags         F04

*** Test Cases ***
TC-F04-01 Create Document Folder Structure
    [Documentation]    A user can create a cabinet and a cabinet inside it.
    [Tags]    positive
    Given a parent cabinet exists
    When a child cabinet is created inside the parent cabinet
    Then the child cabinet is shown inside the parent cabinet

TC-F04-02 Move Document Between Folders
    [Documentation]    A document can be moved from the parent cabinet to the child cabinet.
    [Tags]    positive
    Given a document with a file exists
    And the document is added to the parent cabinet
    And the document is shown in the parent cabinet
    When the document is moved from the parent cabinet to the child cabinet
    Then the document is shown in the child cabinet
    And the document is no longer shown in the parent cabinet

TC-F04-03 Verify Organisation Hierarchy
    [Documentation]    The child cabinet sits under the parent and is not at the top level.
    [Tags]    positive
    Given the parent and child cabinets exist
    Then the child cabinet is shown inside the parent cabinet
    And the parent is a top-level cabinet and the child is not

TC-F04-04 Cabinet Cannot Be Its Own Parent
    [Documentation]    Mayan must reject a request that makes a cabinet its own parent.
    ...                Known issue: Mayan answers HTTP 500 (server error) instead of a 4xx validation error.
    [Tags]    negative
    Given a separate top-level cabinet exists
    When I try to make that cabinet its own parent
    Then Mayan rejects the request
    And the separate cabinet is still a top-level cabinet

TC-F04-05 Cabinet Cannot Be Moved Under Its Own Child
    [Documentation]    Mayan must reject a request that would create a loop in the hierarchy.
    ...                Known issue: Mayan answers HTTP 500 (server error) instead of a 4xx validation error.
    [Tags]    negative
    Given the parent and child cabinets exist
    When I try to move the parent cabinet under its child cabinet
    Then Mayan rejects the request
    And the hierarchy is unchanged

TC-F04-06 Missing Document Cannot Be Added To A Cabinet
    [Documentation]    Mayan must reject a request to add a document that does not exist.
    [Tags]    negative
    Given a separate top-level cabinet exists
    When I try to add a document that does not exist to that cabinet
    Then Mayan rejects the request as invalid

*** Keywords ***
Setup F04
    API Session
    Login As Admin
    ${parent}=    Unique Name    QA_Parent
    ${child}=     Unique Name    QA_Child
    ${doc}=       Unique Name    QA_Doc
    Set Suite Variable    ${PARENT}    ${parent}
    Set Suite Variable    ${CHILD}     ${child}
    Set Suite Variable    ${DOC}       ${doc}

A parent cabinet exists
    ${id}=    API Create Cabinet    ${PARENT}
    Set Suite Variable    ${PARENT_ID}    ${id}

A child cabinet is created inside the parent cabinet
    ${id}=    API Create Cabinet    ${CHILD}    ${PARENT_ID}
    Set Suite Variable    ${CHILD_ID}    ${id}

The parent and child cabinets exist
    Variable Should Exist    \${PARENT_ID}    The parent cabinet was not created: run TC-F04-01 first
    Variable Should Exist    \${CHILD_ID}     The child cabinet was not created: run TC-F04-01 first

The child cabinet is shown inside the parent cabinet
    Cabinet Should Show    ${PARENT_ID}    ${CHILD}

A document with a file exists
    ${id}=    API Upload Document    ${SAMPLE_FILE}    ${DOC}
    Set Suite Variable    ${DOC_ID}    ${id}

The document is added to the parent cabinet
    API Add Document To Cabinet    ${PARENT_ID}    ${DOC_ID}

The document is shown in the parent cabinet
    Wait Until Keyword Succeeds    60s    5s    Cabinet Should Show    ${PARENT_ID}    ${DOC}

The document is moved from the parent cabinet to the child cabinet
    API Remove Document From Cabinet    ${PARENT_ID}    ${DOC_ID}
    API Add Document To Cabinet    ${CHILD_ID}    ${DOC_ID}

The document is shown in the child cabinet
    Wait Until Keyword Succeeds    60s    5s    Cabinet Should Show    ${CHILD_ID}    ${DOC}

The document is no longer shown in the parent cabinet
    Cabinet Should Not Show    ${PARENT_ID}    ${PARENT}    ${DOC}

The parent is a top-level cabinet and the child is not
    [Documentation]    The cabinet list page is split into pages and grows with every test run,
    ...                so this check reads the cabinet data: the parent has no parent and the
    ...                child's parent is the parent cabinet.
    Cabinet Parent Should Be    ${PARENT_ID}    ${None}
    Cabinet Parent Should Be    ${CHILD_ID}     ${PARENT_ID}

A separate top-level cabinet exists
    ${name}=    Unique Name    QA_Solo
    ${id}=    API Create Cabinet    ${name}
    Set Test Variable    ${SOLO}       ${name}
    Set Test Variable    ${SOLO_ID}    ${id}

I try to make that cabinet its own parent
    ${status}=    Try To Set Cabinet Parent    ${SOLO_ID}    ${SOLO_ID}
    Set Test Variable    ${STATUS}    ${status}

I try to move the parent cabinet under its child cabinet
    ${status}=    Try To Set Cabinet Parent    ${PARENT_ID}    ${CHILD_ID}
    Set Test Variable    ${STATUS}    ${status}

I try to add a document that does not exist to that cabinet
    &{body}=    Create Dictionary    document=999999
    ${resp}=    POST On Session    mayan    /api/v4/cabinets/${SOLO_ID}/documents/add/    json=${body}    expected_status=any
    Log    Mayan answered ${resp.status_code}
    Set Test Variable    ${STATUS}    ${resp.status_code}

Mayan rejects the request
    Should Be True    ${STATUS} >= 400    Mayan accepted an invalid request (HTTP ${STATUS})

Mayan rejects the request as invalid
    Should Be True    400 <= ${STATUS} < 500    Expected a client error but Mayan answered HTTP ${STATUS}

The separate cabinet is still a top-level cabinet
    Cabinet Parent Should Be    ${SOLO_ID}    ${None}
    Cabinet Should Show    ${SOLO_ID}    ${SOLO}

The hierarchy is unchanged
    Cabinet Parent Should Be    ${PARENT_ID}    ${None}
    Cabinet Parent Should Be    ${CHILD_ID}     ${PARENT_ID}
    Cabinet Should Show    ${PARENT_ID}    ${CHILD}

Try To Set Cabinet Parent
    [Documentation]    Ask Mayan to set a cabinet's parent and return the HTTP status code.
    [Arguments]    ${cabinet_id}    ${new_parent_id}
    &{body}=    Create Dictionary    parent=${new_parent_id}
    ${resp}=    PATCH On Session    mayan    /api/v4/cabinets/${cabinet_id}/    json=${body}    expected_status=any
    Log    Mayan answered ${resp.status_code}
    RETURN    ${resp.status_code}

Cabinet Parent Should Be
    [Arguments]    ${cabinet_id}    ${expected_parent}
    ${resp}=    GET On Session    mayan    /api/v4/cabinets/${cabinet_id}/
    Should Be Equal    ${resp.json()}[parent_id]    ${expected_parent}

Open Cabinet By Id
    [Arguments]    ${id}
    Go To    ${BASE_URL}/#/cabinets/cabinets/${id}/
    Reload Page

Cabinet Should Show
    [Arguments]    ${id}    ${text}
    Open Cabinet By Id    ${id}
    Wait Until Page Contains    ${text}    timeout=10s

Cabinet Should Not Show
    [Arguments]    ${id}    ${own_label}    ${text}
    Open Cabinet By Id    ${id}
    Wait Until Page Contains    ${own_label}    timeout=10s
    Page Should Not Contain    ${text}
