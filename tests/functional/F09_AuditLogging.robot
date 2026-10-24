*** Settings ***
Documentation     F09 - Audit Logging (Mayan Events page).
...               Author: Roshan Khati.
...               Tests 01-02 check the audit trail for a login and a document upload;
...               tests 03-04 check it for a failed login and a deleted document.
Resource          ../resources/common.resource
Suite Setup       API Session
Suite Teardown    Close All Browsers
Test Tags         F09

*** Test Cases ***
TC-F09-01 Audit Log Created After Login
    [Documentation]    A successful login produces a "User login succeeded" entry for admin.
    [Tags]    positive
    Given I am an administrator
    When I log in to Mayan
    Then the Events list shows a successful login for admin

TC-F09-02 Audit Log Created After Document Upload
    [Documentation]    Creating a document produces a "Document created" entry with its name.
    [Tags]    positive
    Given I am logged in to Mayan
    When a new document is created and its file attached
    Then the Events list shows that the document was created

TC-F09-03 Audit Log Created After Failed Login
    [Documentation]    A login with a wrong password is refused and recorded as "User login failed".
    ...                The check is that the failed attempt appears just before my later successful login.
    [Tags]    negative
    Given I try to log in with a wrong password
    When I log in with the correct password
    Then the Events list shows the failed login just before my login

TC-F09-04 Audit Log Created After Document Deletion
    [Documentation]    Deleting a document is recorded as "Document trashed" with the document name.
    [Tags]    negative
    Given I am logged in to Mayan
    And a new document is created and its file attached
    When the document is deleted
    Then the Events list shows that the document was trashed

*** Keywords ***
I am an administrator
    No Operation

I log in to Mayan
    Login As Admin

I am logged in to Mayan
    Login As Admin

The Events list shows a successful login for admin
    Wait Until Keyword Succeeds    30s    3s
    ...    Events Page Should Show    User login succeeded    User: admin

A new document is created and its file attached
    ${label}=    Unique Name    F09_Doc
    ${id}=    API Upload Document    ${SAMPLE_FILE}    ${label}
    Set Test Variable    ${DOC_LABEL}    ${label}
    Set Test Variable    ${DOC_ID}       ${id}

The Events list shows that the document was created
    Wait Until Keyword Succeeds    60s    5s
    ...    Events Page Should Show    Document created    ${DOC_LABEL}

I try to log in with a wrong password
    Close All Browsers
    Open Mayan
    Wait Until Element Is Visible    ${LOC_USERNAME}    timeout=20s
    Sleep    2s
    Input Text        ${LOC_USERNAME}    ${ADMIN_USER}
    Input Password    ${LOC_PASSWORD}    definitely_not_the_password
    Press Keys        ${LOC_PASSWORD}    RETURN
    Sleep    3s
    Element Should Be Visible    ${LOC_USERNAME}    The wrong password was not refused

I log in with the correct password
    Login As Admin

The Events list shows the failed login just before my login
    Wait Until Keyword Succeeds    30s    3s    Failed Login Should Follow Latest Login

The document is deleted
    ${resp}=    DELETE On Session    mayan    /api/v4/documents/${DOC_ID}/    expected_status=any
    Log    Mayan answered ${resp.status_code}
    Should Be True    200 <= ${resp.status_code} < 300    Deleting the document answered HTTP ${resp.status_code}

The Events list shows that the document was trashed
    Wait Until Keyword Succeeds    60s    5s
    ...    Events Page Should Have A Row Containing    Document trashed    ${DOC_LABEL}

Events Page Should Show
    [Arguments]    @{texts}
    Go To    ${EVENTS_URL}
    Reload Page
    FOR    ${t}    IN    @{texts}
        Wait Until Page Contains    ${t}    timeout=10s
    END

Events Page Should Have A Row Containing
    [Documentation]    Open the Events list and check that one single row holds all the given texts.
    [Arguments]    @{needles}
    ${rows}=    Open Events And Read Rows
    FOR    ${row}    IN    @{rows}
        ${all}=    Row Contains All    ${row}    @{needles}
        IF    ${all}    RETURN
    END
    Fail    No single Events row contains: ${needles}

Failed Login Should Follow Latest Login
    ${rows}=    Open Events And Read Rows
    ${ok}=     Find First Row Index    ${rows}    User login succeeded
    ${bad}=    Find First Row Index    ${rows}    User login failed
    Should Be True    ${ok} >= 0    No successful login row was found on the first Events page
    Should Be True    ${bad} >= 0    No failed login row was found on the first Events page
    ${gap}=    Evaluate    abs(${bad} - ${ok})
    Should Be True    ${gap} <= 5    The failed login is ${gap} rows away from the latest login
    ${failed_row}=    Get From List    ${rows}    ${bad}
    Should Contain    ${failed_row}    admin
    Should Contain    ${failed_row}    Failure

Open Events And Read Rows
    Go To    ${EVENTS_URL}
    Reload Page
    Wait Until Page Contains Element    xpath=(//table)[1]//tr[2]    timeout=15s
    ${rows}=    Wait Until Keyword Succeeds    3x    2s    Read Events Rows
    RETURN    ${rows}

Read Events Rows
    ${elements}=    Get WebElements    xpath=(//table)[1]//tr
    ${texts}=    Create List
    FOR    ${el}    IN    @{elements}
        ${t}=    Get Text    ${el}
        Append To List    ${texts}    ${t}
    END
    RETURN    ${texts}

Row Contains All
    [Arguments]    ${row}    @{needles}
    FOR    ${n}    IN    @{needles}
        IF    $n not in $row    RETURN    ${False}
    END
    RETURN    ${True}

Find First Row Index
    [Arguments]    ${rows}    ${needle}
    ${i}=    Set Variable    ${0}
    FOR    ${row}    IN    @{rows}
        IF    $needle in $row    RETURN    ${i}
        ${i}=    Evaluate    ${i} + 1
    END
    RETURN    ${-1}
