*** Settings ***
Documentation     N02 - API access control checks. These supplement the OWASP ZAP scan,
...               which only covered unauthenticated pages. Author: Roshan Khati.
Resource          ../resources/common.resource
Suite Setup       API Session
Test Tags         N02    security

*** Test Cases ***
TC-N02-01 Anonymous User Cannot List Cabinets
    [Documentation]    Without logging in, the cabinet list must contain no data.
    Given a cabinet exists
    When someone who is not logged in asks the API for the cabinet list
    Then the response contains no data

TC-N02-02 Anonymous User Cannot List Documents
    [Documentation]    Without logging in, the document list must contain no data.
    When someone who is not logged in asks the API for the document list
    Then the response contains no data

TC-N02-03 Anonymous User Cannot Read A Specific Cabinet
    [Documentation]    Without logging in, a cabinet that exists must not be readable.
    Given a cabinet exists
    When someone who is not logged in asks the API for that cabinet
    Then the request is refused or the cabinet is hidden

TC-N02-04 Wrong Password Is Rejected
    [Documentation]    A request with a wrong password must not return data.
    When someone uses a wrong password to ask the API for the cabinet list
    Then the request is refused

*** Keywords ***
A cabinet exists
    ${name}=    Unique Name    QA_Access
    ${id}=    API Create Cabinet    ${name}
    Set Test Variable    ${CABINET_ID}    ${id}

Someone who is not logged in asks the API for the cabinet list
    Create Session    anon_cabinets    ${BASE_URL}
    ${resp}=    GET On Session    anon_cabinets    /api/v4/cabinets/    expected_status=any
    Set Test Variable    ${RESPONSE}    ${resp}

Someone who is not logged in asks the API for the document list
    Create Session    anon_documents    ${BASE_URL}
    ${resp}=    GET On Session    anon_documents    /api/v4/documents/    expected_status=any
    Set Test Variable    ${RESPONSE}    ${resp}

Someone who is not logged in asks the API for that cabinet
    Create Session    anon_one    ${BASE_URL}
    ${resp}=    GET On Session    anon_one    /api/v4/cabinets/${CABINET_ID}/    expected_status=any
    Set Test Variable    ${RESPONSE}    ${resp}

Someone uses a wrong password to ask the API for the cabinet list
    ${auth}=    Create List    ${ADMIN_USER}    definitely_not_the_password
    Create Session    wrong_password    ${BASE_URL}    auth=${auth}
    ${resp}=    GET On Session    wrong_password    /api/v4/cabinets/    expected_status=any
    Set Test Variable    ${RESPONSE}    ${resp}

The response contains no data
    IF    $RESPONSE.status_code == 200
        Should Be Equal As Integers    ${RESPONSE.json()}[count]    0
    ELSE
        Should Be True    $RESPONSE.status_code in (401, 403)
    END

The request is refused or the cabinet is hidden
    Should Be True    $RESPONSE.status_code in (401, 403, 404)    Anonymous access answered HTTP ${RESPONSE.status_code}

The request is refused
    Should Be True    $RESPONSE.status_code in (401, 403)    Wrong password answered HTTP ${RESPONSE.status_code}
