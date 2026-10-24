*** Settings ***
Resource          ../resources/common.resource
Suite Setup       API Session

*** Test Cases ***
Upload Attaches File
    ${id}=    API Upload Document    ${SAMPLE_FILE}    api_check
    Log To Console    DOCUMENT ID ${id}