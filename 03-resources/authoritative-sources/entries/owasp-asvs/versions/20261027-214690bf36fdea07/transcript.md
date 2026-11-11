# Trascrizione della fonte: OWASP Application Security Verification Standard 5.0.0  Ente: OWASP ASVS contributors Fonte originale: https://raw.githubusercontent.com/OWASP/ASVS/v5.0.0/5.0/OWASP_Application_Security_Verification_Standard_5.0.0_en.pdf SHA-256 originale: A2FA1BBE38F12CAC86D3A0F0023327E9772201F65A7F741F282F5E785D268FC5 Riutilizzo: OWASP e autori ASVS, CC BY-SA 4.0. Trascrizione derivata per sola conversione di formato, stessa licenza. Requisiti per applicazioni e servizi web; citare sempre versione e identificatore. Condizioni: https://raw.githubusercontent.com/OWASP/ASVS/v5.0.0/LICENSE.md  Conversione locale di formato; revisione separata dalla estrazione. Non costituisce una dichiarazione di vigenza o conformita.  --- 
| Application | Security | Verification |
| ----------- | -------- | ------------ |
Standard
Version5.0.0
May2025

ApplicationSecurityVerificationStandard May2025
Contents
Frontispiece 7
AbouttheStandard . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
CopyrightandLicense . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
ProjectLeads . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
WorkingGroup . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
OtherMajorContributors . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
OtherContributorsandReviewers . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 8
Preface 8
Introduction . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 8
Principlesbehindversion5.0 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 8
Lookingahead . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 9
WhatistheASVS? 9
ScopeoftheASVS . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 9
Application . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 10
Security . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 10
Verification . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 10
Standard . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 10
Requirement . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 11
Documentedsecuritydecisions . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 11
ApplicationSecurityVerificationLevels . . . . . . . . . . . . . . . . . . . . . . . . . . . 12
Levelevaluation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
Level1 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
Level2 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
Level3 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 14
Whichleveltoachieve . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 14
HowtousetheASVS . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 14
ThestructureoftheASVS . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 14
Releasestrategy . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 14
FlexibilitywiththeASVS . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 15
HowtoReferenceASVSRequirements . . . . . . . . . . . . . . . . . . . . . . . . . 15
ForkingtheASVS . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 16
UsecasesfortheASVS . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 16
AsDetailedSecurityArchitectureGuidance . . . . . . . . . . . . . . . . . . . . . . 16
AsaSpecializedSecureCodingReference . . . . . . . . . . . . . . . . . . . . . . . 16
AsaGuideforAutomatedUnitandIntegrationTests . . . . . . . . . . . . . . . . . . 17
ForSecureDevelopmentTraining . . . . . . . . . . . . . . . . . . . . . . . . . . . 17
AsaFrameworkforGuidingtheProcurementofSecureSoftware . . . . . . . . . . . 17
ApplyingASVSinPractice . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 17
1

ApplicationSecurityVerificationStandard May2025
AssessmentandCertification 18
OWASP’sStanceonASVSCertificationsandTrustMarks . . . . . . . . . . . . . . . . . . . 18
HowtoVerifyASVSCompliance . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
Verificationreporting . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
ScopeofVerification . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
VerificationMechanisms . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
ChangesComparedtov4.x 20
Introduction . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
RequirementPhilosophy . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
ScopeandFocus . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
EmphasisonSecurityGoalsOverMechanisms . . . . . . . . . . . . . . . . . . . . . 20
DocumentedSecurityDecisions . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
StructuralChangesandNewChapters . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
RemovalofDirectMappingstoOtherStandards . . . . . . . . . . . . . . . . . . . . . . . 22
ReducedCouplingwithNISTDigitalIdentityGuidelines . . . . . . . . . . . . . . . . 22
MovingAwayfromCommonWeaknessEnumeration(CWE) . . . . . . . . . . . . . . 22
RethinkingLevelDefinitions . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
EasierEntryLevel . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
TheFallacyofTestability . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 23
NotJustAboutRisk . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 23
V1EncodingandSanitization 23
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 23
V1.1EncodingandSanitizationArchitecture . . . . . . . . . . . . . . . . . . . . . . . . . 24
V1.2InjectionPrevention . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 24
V1.3Sanitization . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 26
V1.4Memory,String,andUnmanagedCode . . . . . . . . . . . . . . . . . . . . . . . . . 27
V1.5SafeDeserialization . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 27
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 28
V2ValidationandBusinessLogic 28
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 28
V2.1ValidationandBusinessLogicDocumentation . . . . . . . . . . . . . . . . . . . . . 29
V2.2InputValidation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 29
V2.3BusinessLogicSecurity . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 30
V2.4Anti‑automation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
V3WebFrontendSecurity 32
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 32
V3.1WebFrontendSecurityDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . 32
2

ApplicationSecurityVerificationStandard May2025
V3.2UnintendedContentInterpretation . . . . . . . . . . . . . . . . . . . . . . . . . . . 32
V3.3CookieSetup . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 33
V3.4BrowserSecurityMechanismHeaders . . . . . . . . . . . . . . . . . . . . . . . . . 33
V3.5BrowserOriginSeparation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 35
V3.6ExternalResourceIntegrity . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 36
V3.7OtherBrowserSecurityConsiderations . . . . . . . . . . . . . . . . . . . . . . . . . 37
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 37
V4APIandWebService 38
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 38
V4.1GenericWebServiceSecurity . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 38
V4.2HTTPMessageStructureValidation . . . . . . . . . . . . . . . . . . . . . . . . . . . 39
V4.3GraphQL . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 40
V4.4WebSocket . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 40
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 41
V5FileHandling 41
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 41
V5.1FileHandlingDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 41
V5.2FileUploadandContent . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 42
V5.3FileStorage . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 42
V5.4FileDownload . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 43
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 43
V6Authentication 44
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 44
V6.1AuthenticationDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 44
V6.2PasswordSecurity . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 45
V6.3GeneralAuthenticationSecurity . . . . . . . . . . . . . . . . . . . . . . . . . . . . 46
V6.4AuthenticationFactorLifecycleandRecovery . . . . . . . . . . . . . . . . . . . . . 47
V6.5GeneralMulti‑factorauthenticationrequirements . . . . . . . . . . . . . . . . . . . 48
V6.6Out‑of‑Bandauthenticationmechanisms . . . . . . . . . . . . . . . . . . . . . . . . 49
V6.7Cryptographicauthenticationmechanism . . . . . . . . . . . . . . . . . . . . . . . 50
V6.8AuthenticationwithanIdentityProvider . . . . . . . . . . . . . . . . . . . . . . . . 51
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 52
V7SessionManagement 52
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 52
V7.1SessionManagementDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . . 53
V7.2FundamentalSessionManagementSecurity . . . . . . . . . . . . . . . . . . . . . . 53
V7.3SessionTimeout . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 54
V7.4SessionTermination . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 54
3

ApplicationSecurityVerificationStandard May2025
V7.5DefensesAgainstSessionAbuse . . . . . . . . . . . . . . . . . . . . . . . . . . . . 55
V7.6FederatedRe‑authentication . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 56
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 56
V8Authorization 56
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 56
V8.1AuthorizationDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 57
V8.2GeneralAuthorizationDesign . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 57
V8.3OperationLevelAuthorization . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 58
V8.4OtherAuthorizationConsiderations . . . . . . . . . . . . . . . . . . . . . . . . . . 58
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 59
V9Self‑containedTokens 59
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 59
V9.1Tokensourceandintegrity . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 59
V9.2Tokencontent . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 60
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 61
V10OAuthandOIDC 61
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 61
V10.1GenericOAuthandOIDCSecurity . . . . . . . . . . . . . . . . . . . . . . . . . . . 63
V10.2OAuthClient . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 63
V10.3OAuthResourceServer . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 64
V10.4OAuthAuthorizationServer . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 65
V10.5OIDCClient . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 67
V10.6OpenIDProvider . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 68
V10.7ConsentManagement . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 68
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 69
V11Cryptography 70
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 70
V11.1CryptographicInventoryandDocumentation . . . . . . . . . . . . . . . . . . . . . 70
V11.2SecureCryptographyImplementation . . . . . . . . . . . . . . . . . . . . . . . . . 71
V11.3EncryptionAlgorithms . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 72
V11.4HashingandHash‑basedFunctions . . . . . . . . . . . . . . . . . . . . . . . . . . 73
V11.5RandomValues . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 73
V11.6PublicKeyCryptography . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 74
V11.7In‑UseDataCryptography . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 74
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 75
V12SecureCommunication 75
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 75
V12.1GeneralTLSSecurityGuidance . . . . . . . . . . . . . . . . . . . . . . . . . . . . 75
4

ApplicationSecurityVerificationStandard May2025
V12.2HTTPSCommunicationwithExternalFacingServices . . . . . . . . . . . . . . . . 76
V12.3GeneralServicetoServiceCommunicationSecurity . . . . . . . . . . . . . . . . . . 76
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 77
V13Configuration 77
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 77
V13.1ConfigurationDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 78
V13.2BackendCommunicationConfiguration . . . . . . . . . . . . . . . . . . . . . . . . 78
V13.3SecretManagement . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 79
V13.4UnintendedInformationLeakage . . . . . . . . . . . . . . . . . . . . . . . . . . . 80
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 81
V14DataProtection 81
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 81
V14.1DataProtectionDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . . . . 81
V14.2GeneralDataProtection . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 82
V14.3Client‑sideDataProtection . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 83
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 84
V15SecureCodingandArchitecture 84
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 84
V15.1SecureCodingandArchitectureDocumentation . . . . . . . . . . . . . . . . . . . 84
V15.2SecurityArchitectureandDependencies . . . . . . . . . . . . . . . . . . . . . . . 85
V15.3DefensiveCoding . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 86
V15.4SafeConcurrency . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 87
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 88
V16SecurityLoggingandErrorHandling 88
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 88
V16.1SecurityLoggingDocumentation . . . . . . . . . . . . . . . . . . . . . . . . . . . 89
V16.2GeneralLogging . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 89
V16.3SecurityEvents . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 90
V16.4LogProtection . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 91
V16.5ErrorHandling . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 91
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 92
V17WebRTC 92
ControlObjective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 92
V17.1TURNServer . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 93
V17.2Media . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 93
V17.3Signaling . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 95
References . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 95
5

ApplicationSecurityVerificationStandard May2025
AppendixA:Glossary 96
AppendixB:References 102
OWASPCoreProjects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 102
OWASPCheatSheetSeriesproject . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 102
MobileSecurityRelatedProjects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 102
OWASPInternetofThingsrelatedprojects . . . . . . . . . . . . . . . . . . . . . . . . . . 102
OWASPServerlessprojects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 102
Others . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 102
AppendixC:CryptographyStandards 103
CryptographicInventoryandDocumentation . . . . . . . . . . . . . . . . . . . . . . . . 103
EquivalentStrengthsofCryptographicParameters . . . . . . . . . . . . . . . . . . . . . 104
RandomValues . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 104
CipherAlgorithms . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 105
AESCipherModes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 106
KeyWrapping . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 107
AuthenticatedEncryption . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 107
HashFunctions . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 108
HashFunctionsforGeneralUseCases . . . . . . . . . . . . . . . . . . . . . . . . . 108
HashFunctionsforPasswordStorage . . . . . . . . . . . . . . . . . . . . . . . . . . 109
KeyDerivationFunctions(KDFs) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 110
GeneralKeyDerivationFunctions . . . . . . . . . . . . . . . . . . . . . . . . . . . 110
Password‑basedKeyDerivationFunctions . . . . . . . . . . . . . . . . . . . . . . . 110
KeyExchangeMechanisms . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 111
KEXSchemes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 111
Diffie‑Hellmangroups . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 111
MessageAuthenticationCodes(MAC) . . . . . . . . . . . . . . . . . . . . . . . . . . . . 112
DigitalSignatures . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 113
Post‑QuantumEncryptionStandards . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 113
AppendixD:Recommendations 114
Introduction . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 114
Recommended,in‑scopemechanisms . . . . . . . . . . . . . . . . . . . . . . . . . . . . 114
SoftwareSecurityprinciples . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 114
SoftwareSecurityprocesses . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 115
AppendixE‑Contributors 116
6

ApplicationSecurityVerificationStandard May2025
Frontispiece
AbouttheStandard
TheApplicationSecurityVerificationStandardisalistofapplicationsecurityrequirementsthatar‑
chitects,developers,testers,securityprofessionals,toolvendors,andconsumerscanusetodefine,
build,test,andverifysecureapplications.
CopyrightandLicense
Version5.0.0,May2025
Figure1:license
Copyright©2008‑2025TheOWASPFoundation.
ThisdocumentisreleasedundertheCreativeCommonsAttribution‑ShareAlike4.0InternationalLi‑
cense.
For any reuse or distribution, you must clearly communicate the license terms of this work to oth‑
ers.
ProjectLeads
ElarLang JoshCGrossman
JimManico DanielCuthbert
WorkingGroup
TobiasAhnoff RalphAndalis RyanArmstrong GabrielCorona
MeghanJacquot ShanniPrutchi ImanSharafaldin EdenYardeni
OtherMajorContributors
SjoerdLangkemper IsaacLewis
7

ApplicationSecurityVerificationStandard May2025
MarkCarney SandroGauci
OtherContributorsandReviewers
WehaveincludedalistoftheothercontributorsinAppendixE.
Ifacreditismissingfromthe5.xcreditlist,pleaselogaticketatGitHubtoberecognizedinfuture
5.xupdates.
TheApplicationSecurityVerificationStandardbuildsontheworkofthoseinvolvedinASVS1.0(2008)
through4.0(2019). MuchofthestructureandmanyoftheverificationitemsthatremaininASVSto‑
daywereoriginallywrittenbyAndrewvanderStock,MikeBoberski,JeffWilliams,andDaveWich‑
ers, among numerous other contributors. Thank you to everyone who has contributed in the past.
Foracomprehensivelistofearliercontributors,pleaseconsulteachpriorversion.
Preface
WelcometotheApplicationSecurityVerificationStandard(ASVS)Version5.0.
Introduction
Originallylaunchedin2008throughaglobalcommunitycollaboration,theASVSdefinesacompre‑
hensivesetofsecurityrequirementsfordesigning,developing,andtestingmodernwebapplications
andservices.
FollowingthereleaseofASVS4.0in2019anditsminorupdate(v4.0.3)in2021,Version5.0represents
asignificantmilestone—modernizedtoreflectthelatestadvancesinsoftwaresecurity.
ASVS5.0istheresultofextensivecontributionsfromprojectleaders,workinggroupmembers,and
thewiderOWASPcommunitytoupdateandimprovethisimportantstandard.
Principlesbehindversion5.0
Thismajorrevisionhasbeendevelopedwithseveralkeyprinciplesinmind:
• Refined Scope and Focus: This version of the standard has been designed to align more di‑
rectly with the foundational pillars in its name: Application, Security, Verification, and Stan‑
dard. Requirementshavebeenrewrittentoemphasizethepreventionofsecurityflawsrather
thanmandatingspecifictechnicalimplementations. Requirementtextsareintendedtobeself‑
explanatory,explainingwhytheyexist.
8

ApplicationSecurityVerificationStandard May2025
• SupportforDocumentedSecurityDecisions: ASVS5.0introducesrequirementsfordocument‑
ing key security decisions. This enhances traceability and supports context‑sensitive imple‑
mentations, allowing organizationsto tailor their security posture to their specificneeds and
risks.
• UpdatedLevels: While ASVSretainsitsthree‑tier model, theleveldefinitionshaveevolvedto
maketheASVSeasiertoadopt. Level1isdesignedastheinitialsteptoadoptingtheASVS,pro‑
vidingthefirstlayerofdefense. Level2representsacomprehensiveviewofstandardsecurity
practices,andLevel3addressesadvanced,high‑assurancerequirements.
• RestructuredandExpandedContent:ASVS5.0includesapproximately350requirementsacross
17 chapters. Chapters have been reorganized for clarity and usability. A two‑way mapping
betweenv4.0andv5.0isprovidedtofacilitatemigration.
Lookingahead
Just as securing an application is never truly finished, neither is the ASVS. Although Version 5.0 is
a major release, development continues. This release allows the wider community to benefit from
the improvements and additions which have been accumulated but also lays the groundwork for
future enhancements. This could include community‑driven efforts to create implementation and
verificationguidancebuiltontopofthecorerequirementset.
ASVS5.0isdesignedtoserveasareliablefoundationforsecuresoftwaredevelopment. Thecommu‑
nityisinvitedtoadopt,contribute,andbuilduponthisstandardtocollectivelyadvancethestateof
applicationsecurity.
WhatistheASVS?
TheApplicationSecurityVerificationStandard(ASVS)definessecurityrequirementsforwebappli‑
cationsandservices,anditisavaluableresourceforanyoneaimingtodesign,develop,andmaintain
secureapplicationsorevaluatetheirsecurity.
ThischapteroutlinestheessentialaspectsofusingtheASVS,includingitsscope,thestructureofits
priority‑basedlevels,andtheprimaryusecasesforthestandard.
ScopeoftheASVS
ThescopeoftheASVSisdefinedbyitsname: Application,Security,Verification,andStandard. Ites‑
tablisheswhichrequirementsareincludedorexcluded,withtheoverarchinggoalofidentifyingthe
security principles that must be achieved. The scope also considers documentation requirements,
whichserveasthefoundationforimplementationrequirements.
9

ApplicationSecurityVerificationStandard May2025
There is no such thing as scope for attackers. Therefore, ASVS requirements should be evaluated
alongsideguidanceforotheraspectsoftheapplicationlifecycle,includingCI/CDprocesses,hosting,
andoperationalactivities.
Application
ASVSdefinesan“application”asthesoftwareproductbeingdeveloped,intowhichsecuritycontrols
mustbeintegrated. ASVSdoesnotprescribedevelopmentlifecycleactivitiesordictatehowtheap‑
plication should be built via a CI/CD pipeline; instead, it specifies the security outcomes that must
beachievedwithintheproductitself.
Componentsthatserve,modify,orvalidateHTTPtraffic,suchasWebApplicationFirewalls(WAFs),
load balancers, or proxies, may be considered part of the application for those specific purposes,
as some security controls depend directly on them or can be implemented through them. These
components should be considered for requirements related to cached responses, rate limiting, or
restrictingincomingandoutgoingconnectionsbasedonsourceanddestination.
Conversely,ASVSgenerallyexcludesrequirementsthatarenotdirectlyrelevanttotheapplicationor
whereconfigurationisoutsidetheapplication’sresponsibility. Forexample,DNSissuesaretypically
managedbyaseparateteamorfunction.
Similarly,whiletheapplicationisresponsibleforhowitconsumesinputandproducesoutput,ifan
externalprocessinteractswiththeapplicationoritsdata,itisconsideredoutofscopeforASVS.For
instance, backing up the application or its data is usually the responsibility of an external process
andisnotcontrolledbytheapplicationoritsdevelopers.
Security
Every requirement must have a demonstrable impact on security. The absence of a requirement
mustresultinalesssecureapplication,andimplementingtherequirementmustreduceeitherthe
likelihoodortheimpactofasecurityrisk.
All other considerations, such as functional aspects, code style, or policy requirements, are out of
scope.
Verification
Therequirementmustbeverifiable,andtheverificationmustresultina“fail”or“pass”decision.
Standard
TheASVSisdesignedtobeacollectionofsecurityrequirementstobeimplementedtocomplywith
thestandard. Thismeansthatrequirementsarelimitedtodefiningthesecuritygoaltoachievethat.
OtherrelatedinformationcanbebuiltontopofASVSorlinkedviamappings.
10

ApplicationSecurityVerificationStandard May2025
Specifically,OWASPhasmanyprojects,andtheASVSdeliberatelyavoidsoverlappingwiththecon‑
tent in other projects. For example, developers may have a question, “how do I implement a par‑
ticularrequirementinmyparticulartechnologyorenvironment,”andthisshouldbecoveredbythe
Cheat Sheet Series project. Verifiers may have a question “how do I test this requirement in this
environment,”andthisshouldbecoveredbytheWebSecurityTestingGuideproject.
Whilst the ASVS is not just intended for security experts to use, it does expect the reader to have
technicalknowledgetounderstandthecontentortheabilitytoresearchparticularconcepts.
Requirement
ThewordrequirementisusedspecificallyintheASVSasitdescribeswhatmustbeachievedtosatisfy
it. TheASVSonlycontainsrequirements(must)anddoesnotcontainrecommendations(should)as
themaincondition.
In other words, recommendations, whether they are just one of many possible options to solve a
problemorcodestyleconsiderations,donotsatisfythedefinitiontobearequirement.
ASVSrequirementsareintendedtoaddressspecificsecurityprincipleswithoutbeingtooimplemen‑
tationortechnology‑specific,atthesametime,beingself‑explanatoryastowhytheyexist. Thisalso
meansthatrequirementsarenotbuiltaroundaparticularverificationmethodorimplementation.
Documentedsecuritydecisions
Insoftwaresecurity,planningsecuritydesignandthemechanismstobeusedearlyonwillleadtoa
moreconsistentandreliableimplementationinthefinishedproductorfeature.
Additionally, forcertainrequirements, implementationwillbecomplicatedandveryspecifictoan
application’s needs. Common examples include permissions, input validation, and protective con‑
trolsarounddifferentlevelsofsensitivedata.
To account for this, rather than sweeping statements like “all data must be encrypted”or trying to
covereverypossibleusecaseinarequirement,documentationrequirementswereincludedwhich
mandatethattheapplicationdeveloper’sapproachandconfigurationtothesesortsofcontrolsmust
be documented. This can then be reviewed for appropriateness and then the actual implementa‑
tioncanbecomparedtothedocumentationtoassesswhethertheimplementationmatchesexpec‑
tations.
Theserequirementsareintendedtodocumentthedecisionswhichtheorganizationdevelopingthe
applicationhastakenregardinghowtoimplementcertainsecurityrequirements.
Documentationrequirementsarealwaysinthefirstsectionofachapter(althoughnoteverychapter
hasthem)andalwayshavearelatedimplementationrequirementwherethedecisionsthataredoc‑
umentedshouldactuallybeputintoplace. Thepointhereisthatverifyingthatthedocumentation
isinplaceandthattheactualimplementationaretwoseparateactivities.
11

ApplicationSecurityVerificationStandard May2025
Therearetwokeydriversforincludingtheserequirements. Thefirstdriveristhatasecurityrequire‑
mentwillofteninvolveenforcingrulese.g.,whatkindoffiletypesareallowedtobeuploaded,what
businesscontrolsshouldbeenforced, whataretheallowedcharactersforaparticularfield. These
ruleswilldifferforeveryapplication,andtherefore,theASVScannotprescriptivelydefinewhatthey
shouldbe,norwillacheatsheetormoredetailedresponsehelpinthiscase. Similarly,withoutthese
decisionsbeingdocumented,itwillnotbepossibletoperformverificationoftherequirementsthat
implementthesedecisions.
The second driver is that for certain requirements, it is important to provide an application devel‑
opment with flexibility regarding how to address particular security challenges. For example, in
previous ASVS versions, session timeout rules were very prescriptive. Practically speaking, many
applications, especially those that are consumer‑facing, have much more relaxed rules and prefer
toimplementothermitigationcontrolsinstead. Documentationrequirements,therefore,explicitly
allowforflexibilityaroundthis.
Clearly,itisnotexpectedthatindividualdeveloperswillbemakinganddocumentingthesedecisions
butrathertheorganizationasawholewillbetakingthosedecisionsandmakingsurethattheyare
communicatedtodeveloperswhothenmakesuretofollowthem.
Providingdeveloperswithspecificationsanddesignsfornewfeaturesandfunctionalityisastandard
partofsoftwaredevelopment. Similarly, developersareexpectedtousecommoncomponentsand
userinterfacemechanismsratherthanjustmakingtheirowndecisionseachtime. Assuch,extend‑
ingthistosecurityshouldnotbeseenassurprisingorcontroversial.
There is also flexibility around how to achieve this. Security decisions might be documented in a
literaldocument,whichdevelopersareexpectedtoreferto. Alternatively,securitydecisionscould
bedocumentedandimplementedinacommoncodelibrarythatalldevelopersaremandatedtouse.
Inbothcases,thedesiredresultisachieved.
ApplicationSecurityVerificationLevels
TheASVSdefinesthreesecurityverificationlevels,witheachlevelincreasingindepthandcomplex‑
ity. Thegeneralaimisfororganizationstostartwiththefirstleveltoaddressthemostcriticalsecurity
concerns,andthenmoveuptothehigherlevelsaccordingtotheorganizationandapplicationneeds.
LevelsmaybepresentedasL1,L2,andL3inthedocumentandinrequirementtexts.
EachASVSlevelindicatesthesecurityrequirementsthatarerequiredtoachievefromthatlevel,with
thehigherremaininglevelrequirementsasrecommendations.
Inordertoavoidduplicaterequirementsorrequirementsthatarenolongerrelevantathigherlevels,
somerequirementsapplytoaparticularlevelbuthavemorestringentconditionsforhigherlevels.
12

ApplicationSecurityVerificationStandard May2025
Levelevaluation
Levelsaredefinedbypriority‑basedevaluationofeachrequirementbasedonexperienceimplement‑
ingandtestingsecurityrequirements. Themainfocusisoncomparingriskreductionwiththeeffort
toimplementtherequirement. Anotherkeyfactoristokeepalowbarriertoentry.
Riskreductionconsiderstheextenttowhichtherequirementreducesthelevelofsecurityriskwithin
theapplication,takingintoaccounttheclassicConfidentiality,Integrity,andAvailabilityimpactfac‑
torsaswellasconsideringwhetherthisisaprimarylayerofdefenseorwhetheritwouldbeconsid‑
ereddefenseindepth.
Therigorousdiscussionsaroundboththecriteriaandthelevelingdecisionshaveresultedinanal‑
locationwhichshouldholdtrueforthevastmajorityofcases,whilstacceptingthatitmaynotbea
100% fit for every situation. This means that in certain cases, organizations may wish to prioritize
requirementsfromahigherlevelearlieronbasedontheirownspecificriskconsiderations.
Thetypesofrequirementsineachlevelcouldbecharacterizedasfollows.
Level1
This level contains the minimum requirements to consider when securing an application and rep‑
resentsacriticalstartingpoint. Thislevelcontainsaround20%oftheASVSrequirements. Thegoal
forthislevelistohaveasfewrequirementsaspossible,todecreasethebarriertoentry.
Theserequirementsaregenerallycriticalorbasic,first‑layerofdefenserequirementsforpreventing
commonattacksthatdonotrequireothervulnerabilitiesorpreconditionstobeexploitable.
Inadditiontothefirstlayerofdefenserequirements, somerequirementshavelessofanimpactat
higherlevels,suchasrequirementsrelatedtopasswords. ThosearemoreimportantforLevel1,as
fromhigherlevels,themulti‑factorauthenticationrequirementsbecomerelevant.
Level1isnotnecessarilypenetrationtestablebyanexternaltesterwithoutinternalaccesstodocu‑
mentationorcode(suchas“blackbox”testing),althoughthelowernumberofrequirementsshould
makeiteasiertoverify.
Level2
Mostapplicationsshouldbestrivingtoachievethislevelofsecurity. Around50%oftherequirements
intheASVSareL2meaningthatanapplicationneedstoimplementaround70%oftherequirements
intheASVS(alloftheL1andL2requirements)inordertocomplywithL2.
Theserequirementsgenerallyrelatetoeitherlesscommonattacksormorecomplicatedprotections
againstcommonattacks. Theymaystillbeafirstlayerofdefense,ortheymayrequirecertainpre‑
conditionsfortheattacktobesuccessful.
13

ApplicationSecurityVerificationStandard May2025
Level3
This level should be the goal for applications looking to demonstrate the highest levels of security
andprovidesthefinal~30%ofrequirementstocomplywith.
Requirementsinthissectionaregenerallyeitherdefense‑in‑depthmechanismsorotherusefulbut
hard‑to‑implementcontrols.
Whichleveltoachieve
The priority‑based levels are intended to provide a reflection of the application security maturity
of the organization and the application. Rather than the ASVS prescriptively stating what level an
applicationshouldbeat,anorganizationshouldanalyzeitsrisksanddecidewhatlevelitbelievesit
should be at, depending on the sensitivity of the application and of course, the expectations of the
application’susers.
Forexample,anearly‑stagestartupthatisonlycollectinglimitedsensitivedatamaydecidetofocus
on Level 1 for its initial security goals, but a bank may have difficulty justifying anything less than
Level3toitscustomersforitsonlinebankingapplication.
HowtousetheASVS
ThestructureoftheASVS
TheASVSismadeupofatotalofaround350requirementswhicharedividedinto17chapters,each
ofwhichisfurtherdividedintosections.
Theaimofthechapterandsectiondivisionistosimplifychoosingorfilteringoutchaptersandsec‑
tionsbasedonthewhatisrelevantfortheapplication. Forexample,foramachine‑to‑machineAPI,
the requirements in chapter V3 related to web frontends will not be relevant. If there is no use of
OAuthorWebRTC,thenthosechapterscanbeignoredaswell.
Releasestrategy
ASVSreleasesfollowthepattern“Major.Minor.Patch”andthenumbersprovideinformationonwhat
haschangedwithintherelease. Inamajorrelease,thefirstnumberwillchange,inaminorrelease,
thesecondnumberwillchange,andinapatchrelease,thethirdnumberwillchange.
• Major release ‑ Full reorganization, almost everything may have changed, including require‑
mentnumbers. Reevaluationforcompliancewillbenecessary(forexample,4.0.3‑>5.0.0).
• Minorrelease‑Requirementsmaybeaddedorremoved, butoverallnumberingwillstaythe
same. Reevaluationforcompliancewillbenecessary,butshouldbeeasier(forexample,5.0.0
‑>5.1.0).
14

ApplicationSecurityVerificationStandard May2025
• Patchrelease‑Requirementsmayberemoved(forexample,iftheyareduplicatesoroutdated)
ormadelessstringent,butanapplicationthatcompliedwiththepreviousreleasewillcomply
withthepatchreleaseaswell(forexample,5.0.0‑>5.0.1).
TheabovespecificallyrelatestotherequirementsintheASVS.Changestosurroundingtextandother
contentsuchastheappendiceswillnotbeconsideredtobeabreakingchange.
FlexibilitywiththeASVS
Several of the points described above, such as documentation requirements and the levels mecha‑
nism,providetheabilitytousetheASVSinamoreflexibleandorganization‑specificway.
Additionally, organizations are strongly encouraged to create an organization‑ or domain‑specific
forkthatadjustsrequirementsbasedonthespecificcharacteristicsandrisklevelsoftheirapplica‑
tions. However,itisimportanttomaintaintraceabilitysothatpassingrequirement4.1.1meansthe
sameacrossallversions.
Ideally, each organization should create its own tailored ASVS, omitting irrelevant sections (e.g.,
GraphQL, WebSockets, SOAP, if unused). An organization‑specific ASVS version or supplement is
also a good place to provide organization‑specific implementation guidance, detailing libraries or
resourcestousewhencomplyingwithrequirements.
HowtoReferenceASVSRequirements
Eachrequirementhasanidentifierintheformat<chapter>.<section>.<requirement>,whereeach
elementisanumber. Forexample,1.11.3.
• The <chapter> value corresponds to the chapter from which the requirement comes; for ex‑
ample,all1.#.#requirementsarefromthe‘EncodingandSanitization’chapter.
• The <section> value corresponds to the section within that chapter where the requirement
appears, for example: all 1.2.# requirements are in the ‘Injection Prevention’section of the
‘EncodingandSanitization’chapter.
• The <requirement> value identifies the specific requirement within the chapter and section,
forexample,1.2.5whichasofversion5.0.0ofthisstandardis:
Verify that the application protects against OS command injection and that operating system
callsuseparameterizedOSqueriesorusecontextualcommandlineoutputencoding.
Since the identifiers may change between versions of the standard, it is preferable for other docu‑
ments,reports,ortoolstousethefollowingformat:v<version>-<chapter>.<section>.<requirement>,
where: ‘version’istheASVSversiontag. Forexample: v5.0.0-1.2.5wouldbeunderstoodtomean
specifically the 5th requirement in the ‘Injection Prevention’section of the ‘Encoding and Sanitiza‑
tion’chapterfromversion5.0.0. (Thiscouldbesummarizedasv<version>-<requirement_identifier>.)
15

ApplicationSecurityVerificationStandard May2025
Note: Thevprecedingtheversionnumberintheformatshouldalwaysbelowercase.
If identifiers are used without including the v<version> element then they should be assumed to
refer to the latest Application Security Verification Standard content. As the standard grows and
changes this becomes problematic, which is why writers or developers should include the version
element.
ASVSrequirementlistsaremadeavailableinCSV,JSON,andotherformatswhichmaybeusefulfor
referenceorprogrammaticuse.
ForkingtheASVS
Organizations can benefit from adopting ASVS by choosing one of the three levels or by creating a
domain‑specificforkthatadjustsrequirementsperapplicationrisklevel. Thistypeofforkisencour‑
aged,providedthatitmaintainstraceabilitysothatpassingrequirement4.1.1meansthesameacross
allversions.
Ideally, each organization should create its own tailored ASVS, omitting irrelevant sections (e.g.,
GraphQL, Websockets, SOAP, if unused). Forking should start with ASVS Level 1 as a baseline, ad‑
vancingtoLevels2or3basedontheapplication’srisk.
UsecasesfortheASVS
TheASVScanbeusedtoassessthesecurityofanapplicationandthisisexploredinmoredepthin
thenextchapter. However,severalotherpotentialusesfortheASVS(oraforkedversion)havebeen
identified.
AsDetailedSecurityArchitectureGuidance
OneofthemorecommonusesfortheApplicationSecurityVerificationStandardisasaresourcefor
security architects. There are limited resources available for how to build a secure application ar‑
chitecture, especiallywithmodernapplications. ASVScanbeusedtofillinthosegapsbyallowing
securityarchitectstochoosebettercontrolsforcommonproblems,suchasdataprotectionpatterns
andinputvalidationstrategies. Thearchitectureanddocumentationrequirementswillbeparticu‑
larlyusefulforthis.
AsaSpecializedSecureCodingReference
The ASVS can be used as a basis for preparing a secure coding reference during application devel‑
opment,helpingdeveloperstomakesurethattheykeepsecurityinmindwhentheybuildsoftware.
Whilst the ASVS can be the base, organizations should prepare their own specific guidance which
isclearandunifiedandideallybepreparedbasedonguidancefromsecurityengineersorsecurity
16

ApplicationSecurityVerificationStandard May2025
architects. As an extension to this, organizations are encouraged wherever possible to prepare ap‑
provedsecuritymechanismsandlibrariesthatcanbereferencedintheguidanceandusedbydevel‑
opers.
AsaGuideforAutomatedUnitandIntegrationTests
The ASVS is designed to be highly testable. Some verifications will be technical where as other re‑
quirements(suchasthearchitecturalanddocumentationrequirements)mayrequiredocumentation
orarchitecturereview. Bybuildingunitandintegrationteststhattestandfuzzforspecificandrele‑
vantabusecasesrelatedtotherequirementsthatareverifiablebytechnicalmeans,itshouldbeeasier
tocheckthatthesecontrolsareoperatingcorrectlyoneachbuild. Forexample,additionaltestscan
be crafted for the test suite fora login controller, testing the username parameter for common de‑
faultusernames, accountenumeration, bruteforcing, LDAPandSQLinjection, andXSS.Similarly,
a test on the password parameter should include common passwords, password length, null byte
injection,removingtheparameter,XSS,andmore.
ForSecureDevelopmentTraining
ASVScanalsobeusedtodefinethecharacteristicsofsecuresoftware. Many“securecoding”courses
aresimplyethicalhackingcourseswithalightsmearofcodingtips. Thismaynotnecessarilyhelp
developerstowritemoresecurecode. Instead,securedevelopmentcoursescanusetheASVSwitha
strongfocusonthepositivemechanismsfoundintheASVS,ratherthantheTop10negativethings
nottodo. TheASVSstructurealsoprovidesalogicalstructureforwalkingthroughthedifferenttopics
whensecuringanapplication.
AsaFrameworkforGuidingtheProcurementofSecureSoftware
TheASVSisagreatframeworktohelpwithsecuresoftwareprocurementorprocurementofcustom
developmentservices. Thebuyercansimplysetarequirementthatthesoftwaretheywishtoprocure
mustbedevelopedatASVSlevelX,andrequestthatthesellerprovesthatthesoftwaresatisfiesASVS
levelX.
ApplyingASVSinPractice
Differentthreatshavedifferentmotivations. Someindustrieshaveuniqueinformationandtechnol‑
ogyassetsanddomain‑specificregulatorycompliancerequirements.
Organizations are strongly encouraged to look deeply at their unique risk characteristics based on
the nature of their business, and based upon that risk and business requirements determine the
appropriateASVSlevel.
17

ApplicationSecurityVerificationStandard May2025
AssessmentandCertification
OWASP’sStanceonASVSCertificationsandTrustMarks
OWASP, as a vendor‑neutral nonprofit, does not certify any vendors, verifiers, or software. Any as‑
surance,trustmark,orcertificationclaimingASVScomplianceisnotofficiallyendorsedbyOWASP,
soorganizationsshouldbecautiousofthird‑partyclaimsofASVScertification.
Organizations may offer assurance services, provided they do not claim official OWASP certifica‑
tion.
HowtoVerifyASVSCompliance
The ASVS is deliberately not prescriptive about exactly how to verify compliance at the level of a
testingguide. However,itisimportanttohighlightsomekeypoints.
Verificationreporting
Traditionalpenetrationtestingreportsissues“byexception,”onlylistingfailures. However,anASVS
certificationreportshouldincludescope,asummaryofallrequirementschecked,therequirements
where exceptions were noted, and guidance on resolving issues. Some requirements may be non‑
applicable(e.g.,sessionmanagementinstatelessAPIs),andthismustbenotedinthereport.
ScopeofVerification
An organization developing an application will generally not implement all requirements, as some
maybeirrelevantorlesssignificantbasedonthefunctionalityoftheapplication. Theverifiershould
make the scope of the verification clear including which Level the organization is attempting to
achieve and which requirements were included. This should be from the perspective of what was
includedratherthanwhatwasnotincluded. Theyshouldalsoprovideanopinionontherationaleof
excludingtherequirementswhichhaven’tbeenimplemented.
Thisshouldallowtheconsumerofaverificationreporttounderstandthecontextoftheverification
andmakeaninformeddecisionabouttheleveloftrusttheycanplaceintheapplication.
Certifyingorganizationscanchoosetheirtestingmethodsbutshoulddisclosetheminthereportand
this should ideally be repeatable. Different methods, like manual penetration tests or source code
analysis, may be used to verify aspects such as input validation, depending on the application and
requirements.
18

ApplicationSecurityVerificationStandard May2025
VerificationMechanisms
There are a number of different techniques which may be needed to verify specific ASVS require‑
ments. Asidefrompenetrationtesting(usingvalidcredentialstogetfullapplicationcoverage),veri‑
fyingASVSrequirementsmayrequireaccesstodocumentation,sourcecode,configuration,andthe
peopleinvolvedinthedevelopmentprocess. EspeciallyforverifyingL2andL3requirements. Itis
standardpracticetoproviderobustevidenceoffindingswithdetaileddocumentation,whichmayin‑
cludeworkpapers,screenshots,scripts,andtestinglogs. Merelyrunninganautomatedtoolwithout
thoroughtestingisinsufficientforcertification,aseachrequirementmustbeverifiablytested.
TheuseofautomationtoverifyASVSrequirementsisatopicthatisconstantlyofinterest. Itisthere‑
foreimportanttoclarifysomepointsrelatedtoautomatedandblackboxtesting.
TheRoleofAutomatedSecurityTestingTools
WhenautomatedsecuritytestingtoolssuchasDynamicandStaticApplicationSecurityTestingtools
(DASTandSAST)arecorrectlyimplementedinthebuildpipeline,theymaybeabletoidentifysome
securityissuesthatshouldneverexist. However,withoutcarefulconfigurationandtuningtheywill
notprovidetherequiredcoverageandthelevelofnoisewillpreventrealsecurityissuesfrombeing
identifiedandmitigated.
Whilstthismayprovidecoverageofsomeofthemorebasicandstraightforwardtechnicalrequire‑
mentssuchasthoserelatingtooutputencodingorsanitization,itiscriticaltonotethatthesetools
willbeunableentirelytoverifymanyofthemorecomplicatedASVSrequirementsorthosethatrelate
tobusinesslogicandaccesscontrol.
Forlessstraightforwardrequirements,itislikelythatautomationcanstillbeutilizedbutapplication
specificverificationswillneedtobewrittentoachievethis. Thesemaybesimilartounitandintegra‑
tionteststhattheorganizationmayalreadybeusing. Itmaythereforebepossibletousethisexisting
testautomationinfrastructuretowritetheseASVSspecifictests. Whilstdoingthiswillrequireshort
term investment, the long term benefits being able to continually verify these ASVS requirements
willbesignificant.
Insummary,testableusingautomation!=runninganofftheshelftool.
TheRoleofPenetrationTesting
WhilstL1inversion4.0wasoptimizedfor“blackbox”(nodocumentationandnosource)testingto
occur, even then the standard was clear that it is not an effective assurance activity and should be
activelydiscouraged.
Testing without access to necessary additional information is an inefficient and ineffective mecha‑
nismforsecurityverification,asitmissesoutonthepossibilityofreviewingthesource,identifying
threatsandmissingcontrols,andperformingafarmorethoroughtestinashortertimeframe.
Itisstronglyencouragedtoperformdocumentationorsourcecode‑led(hybrid)penetrationtesting,
which have full access to the application developers and the application’s documentation, rather
19

ApplicationSecurityVerificationStandard May2025
than traditional penetration tests. This will certainly be necessary in order to verify many of the
ASVSrequirements.
ChangesComparedtov4.x
Introduction
Users familiar with version 4.x of the standard may find it helpful to review the key changes intro‑
ducedinversion5.0,includingupdatesincontent,scope,andunderlyingphilosophy.
Ofthe286requirementsinversion4.0.3,only11remainunchanged,while15haveundergoneminor
grammatical adjustments without altering their meaning. In total 109 requirements (38%) are no
longerseparaterequirementsinversion5.0with50simplybeingdeleted,28removedasduplicates
and31mergedintootherrequirements. Theresthavebeenrevisedinsomeway. Evenrequirements
thatwerenotsubstantivelymodifiedhavedifferentidentifiersduetoreorderingorrestructuring.
To facilitate adoption of version 5.0, mapping documents are provided to help users trace how re‑
quirements from version 4.x correspond to those in version 5.0. These mappings are not tied to
releaseversioningandmaybeupdatedorclarifiedasneeded.
RequirementPhilosophy
ScopeandFocus
Version4.xincludedrequirementsthatdidnotalignwiththeintendedscopeofthestandard;these
havebeenremoved. Requirementsthatdidnotmeetthescopecriteriafor5.0orwerenotverifiable
havealsobeenexcluded.
EmphasisonSecurityGoalsOverMechanisms
In version 4.x, many requirements focused on specific mechanisms rather than the underlying se‑
curityobjectives. Inversion5.0,requirementsarecenteredonsecuritygoals,referencingparticular
mechanismsonlywhentheyarethesolepracticalsolution,orprovidingthemasexamplesorsup‑
plementaryguidance.
Thisapproachrecognizesthatmultiplemethodsmayexisttoachieveagivensecurityobjective,and
avoidsunnecessaryprescriptivenessthatcouldlimitorganizationalflexibility.
Additionally,requirementsaddressingthesamesecurityconcernhavebeenconsolidatedwhereap‑
propriate.
20

ApplicationSecurityVerificationStandard May2025
DocumentedSecurityDecisions
Whiletheconceptofdocumentedsecuritydecisionsmayappearnewinversion5.0,itisanevolution
ofearlierrequirementsrelatedtopolicyapplicationandthreatmodelinginversion4.0. Previously,
somerequirementsimplicitlydemandedanalysistoinformtheimplementationofsecuritycontrols,
suchasdeterminingpermittednetworkconnections.
Toensurethatnecessaryinformationisavailableforimplementationandverification,theseexpec‑
tations are now explicitly defined as documentation requirements, making them clear, actionable,
andverifiable.
StructuralChangesandNewChapters
Severalchaptersinversion5.0introduceentirelynewcontent:
• OAuthandOIDC–Giventhewidespreadadoptionoftheseprotocolsforaccessdelegationand
single sign‑on, dedicated requirements have been added to address the diverse scenarios de‑
velopers mayencounter. This areamayeventually evolveintoa standalonestandard, similar
tothetreatmentofMobileandIoTrequirementsinpreviousversions.
• WebRTC–Asthistechnologygainspopularity,itsuniquesecurityconsiderationsandchallenges
arenowaddressedinadedicatedsection.
Effortshavealsobeenmadetoensurethatchaptersandsectionsareorganizedaroundcoherentsets
ofrelatedrequirements.
Thisrestructuringhasledtothecreationofadditionalchapters:
• Self‑contained Tokens –Formerly grouped under session management, self‑contained tokens
are now recognized as a distinct mechanism and a foundational element for stateless com‑
munication (such as in OAuth and OIDC). Due to their unique security implications, they are
addressedinadedicatedchapter,withsomenewrequirementsintroducedinversion5.x.
• WebFrontendSecurity–Withtheincreasingcomplexityofbrowser‑basedapplicationsandthe
riseofAPI‑onlyarchitectures, frontendsecurityrequirementshavebeenseparatedintotheir
ownchapter.
• SecureCodingandArchitecture–Newrequirementsaddressinggeneralsecuritypracticesthat
didnotfitwithinexistingchaptershavebeengroupedhere.
Otherorganizationalchangesinversion5.0weremadetoclarifyintent. Forexample,inputvalida‑
tionrequirementsweremovedalongsidebusinesslogic, reflectingtheirroleinenforcingbusiness
rules,ratherthanbeinggroupedwithsanitizationandencoding.
The former V1 Architecture chapter has been removed. Its initial section contained requirements
thatwereoutofscope,whilesubsequentsectionshavebeenredistributedtorelevantchapters,with
requirementsdeduplicatedandclarifiedasnecessary.
21

ApplicationSecurityVerificationStandard May2025
RemovalofDirectMappingstoOtherStandards
Directmappingstootherstandardshavebeenremovedfromthemainbodyofthestandard. Theaim
istoprepareamappingwiththeOWASPCommonRequirementEnumeration(CRE)project,which
inturnwilllinkASVStoarangeofOWASPprojectsandexternalstandards.
DirectmappingstoCWEandNISTarenolongermaintained,asexplainedbelow.
ReducedCouplingwithNISTDigitalIdentityGuidelines
The NIST Digital Identity Guidelines (SP 800‑63) have long served as a reference for authentication
andauthorizationcontrols. Inversion4.x, certainchapterswerecloselyalignedwithNIST’sstruc‑
tureandterminology.
While these guidelines remain an important reference, strict alignment introduced challenges, in‑
cluding less widely recognized terminology, duplication of similar requirements, and incomplete
mappings. Version5.0movesawayfromthisapproachtoimproveclarityandrelevance.
MovingAwayfromCommonWeaknessEnumeration(CWE)
TheCommonWeaknessEnumeration(CWE)providesausefultaxonomyofsoftwaresecurityweak‑
nesses. However, challenges such as category‑only CWEs, difficulties in mapping requirements to
a single CWE, and the presence of imprecise mappings in version 4.x have led to the decision to
discontinuedirectCWEmappingsinversion5.0.
RethinkingLevelDefinitions
Version4.xdescribedthelevelsasL1(“Minimum”),L2(“Standard”),andL3(“Advanced”),withthe
implicationthatallapplicationshandlingsensitivedatashouldmeetatleastL2.
Version 5.0 addresses several issues with this approach which are described in the following para‑
graphs.
As a practical matter, whereas version 4.x used tick marks for level indicators, 5.x uses a simple
number on all formats of the standard including markdown, PDF, DOCX, CSV, JSON and XML. For
backwardscompatibility,legacyversionsoftheCSV,JSONandXMLoutputswhichstillusetickmarks
arealsogenerated.
EasierEntryLevel
FeedbackindicatedthatthelargenumberofLevel1requirements(~120), combinedwithitsdesig‑
nationasthe“minimum”levelthatisnotgoodenoughformostapplications,discouragedadoption.
22

ApplicationSecurityVerificationStandard May2025
Version5.0aimstolowerthisbarrierbydefiningLevel1primarilyaroundfirst‑layerdefenserequire‑
ments,resultinginclearerandfewerrequirementsatthatlevel. Todemonstratethisnumerically,in
v4.0.3therewere128L1requirementsoutofatotalof278requirements,representing46%. In5.0.0
thereare70L1requirementsoutofatotalof345requirements,representing20%.
TheFallacyofTestability
AkeyfactorinselectingcontrolsforLevel1inversion4.xwastheirsuitabilityforassessmentthrough
“blackbox”externalpenetrationtesting. However,thisapproachwasnotfullyalignedwiththeintent
ofLevel1astheminimumsetofsecuritycontrols. SomeusersarguedthatLevel1wasinsufficient
forsecuringapplications,whileothersfoundittoodifficulttotest.
Relyingontestabilityasacriterionisbothrelativeand,attimes,misleading. Thefactthatarequire‑
mentistestabledoesnotguaranteethatitcanbetestedinanautomatedorstraightforwardmanner.
Moreover,themosteasilytestablerequirementsarenotalwaysthosewiththegreatestsecurityim‑
pactorthesimplesttoimplement.
As such, in version 5.0, the level decisions were made primarily based on risk reduction and also
keepinginmindtheefforttoimplement.
NotJustAboutRisk
The use of prescriptive, risk‑based levels that mandate a specific level for certain applications has
proven to be overly rigid. In practice, the prioritization and implementation of security controls
depend on multiple factors, including both risk reduction and the effort required for implementa‑
tion.
Therefore,organizationsareencouragedtoachievethelevelthattheyfeelliketheyshouldbeachiev‑
ingbasedontheirmaturityandthemessagetheywanttosendtotheirusers.
V1EncodingandSanitization
ControlObjective
Thischapteraddressesthemostcommonwebapplicationsecurityweaknessesrelatedtotheunsafe
processingofuntrusteddata. Suchweaknessescanresultinvarioustechnicalvulnerabilities,where
untrusteddataisinterpretedaccordingtothesyntaxrulesoftherelevantinterpreter.
Formodernwebapplications,itisalwaysbesttousesaferAPIs,suchasparameterizedqueries,auto‑
escaping,ortemplatingframeworks. Otherwise,carefullyperformedoutputencoding,escaping,or
sanitizationbecomescriticaltotheapplication’ssecurity.
Inputvalidationservesasadefense‑in‑depthmechanismtoprotectagainstunexpectedordangerous
content. However,sinceitsprimarypurposeistoensurethatincomingcontentmatchesfunctional
23

ApplicationSecurityVerificationStandard May2025
andbusinessexpectations,requirementsrelatedtothiscanbefoundinthe“ValidationandBusiness
Logic”chapter.
V1.1EncodingandSanitizationArchitecture
Inthesectionsbelow,syntax‑specificorinterpreter‑specificrequirementsforsafelyprocessingun‑
safe content to avoid security vulnerabilities are provided. The requirements in this section cover
the order in which this processing should occur and where it should take place. They also aim to
ensurethatwheneverdataisstored,itremainsinitsoriginalstateandisnotstoredinanencodedor
escapedform(e.g.,HTMLencoding),topreventdoubleencodingissues.
# Description Level
1.1.1 Verifythatinputisdecodedorunescapedintoacanonicalformonlyonce,it 2
isonlydecodedwhenencodeddatainthatformisexpected,andthatthisis
donebeforeprocessingtheinputfurther,forexampleitisnotperformed
afterinputvalidationorsanitization.
1.1.2 Verifythattheapplicationperformsoutputencodingandescapingeitheras 2
afinalstepbeforebeingusedbytheinterpreterforwhichitisintendedorby
theinterpreteritself.
V1.2InjectionPrevention
Outputencodingorescaping, performedclosetooradjacenttoapotentiallydangerouscontext, is
criticaltothesecurityofanyapplication. Typically,outputencodingandescapingarenotpersisted,
butareinsteadusedtorenderoutputsafeforimmediateuseintheappropriateinterpreter. Attempt‑
ing to perform this too early may result in malformed content or render the encoding or escaping
ineffective.
In many cases, software libraries include safe or safer functions that perform this automatically,
althoughitisnecessarytoensurethattheyarecorrectforthecurrentcontext.
# Description Level
1.2.1 VerifythatoutputencodingforanHTTPresponse,HTMLdocument,orXML 1
documentisrelevantforthecontextrequired,suchasencodingtherelevant
charactersforHTMLelements,HTMLattributes,HTMLcomments,CSS,or
HTTPheaderfields,toavoidchangingthemessageordocumentstructure.
24

ApplicationSecurityVerificationStandard May2025
# Description Level
1.2.2 VerifythatwhendynamicallybuildingURLs,untrusteddataisencoded 1
accordingtoitscontext(e.g.,URLencodingorbase64urlencodingforquery
orpathparameters). EnsurethatonlysafeURLprotocolsarepermitted(e.g.,
disallowjavascript: ordata:).
1.2.3 Verifythatoutputencodingorescapingisusedwhendynamicallybuilding 1
JavaScriptcontent(includingJSON),toavoidchangingthemessageor
documentstructure(toavoidJavaScriptandJSONinjection).
1.2.4 Verifythatdataselectionordatabasequeries(e.g.,SQL,HQL,NoSQL, 1
Cypher)useparameterizedqueries,ORMs,entityframeworks,orare
otherwiseprotectedfromSQLInjectionandotherdatabaseinjectionattacks.
Thisisalsorelevantwhenwritingstoredprocedures.
1.2.5 VerifythattheapplicationprotectsagainstOScommandinjectionandthat 1
operatingsystemcallsuseparameterizedOSqueriesorusecontextual
commandlineoutputencoding.
1.2.6 VerifythattheapplicationprotectsagainstLDAPinjectionvulnerabilities,or 2
thatspecificsecuritycontrolstopreventLDAPinjectionhavebeen
implemented.
1.2.7 VerifythattheapplicationisprotectedagainstXPathinjectionattacksby 2
usingqueryparameterizationorprecompiledqueries.
1.2.8 VerifythatLaTeXprocessorsareconfiguredsecurely(suchasnotusingthe“– 2
shell‑escape”flag)andanallowlistofcommandsisusedtopreventLaTeX
injectionattacks.
1.2.9 Verifythattheapplicationescapesspecialcharactersinregularexpressions 2
(typicallyusingabackslash)topreventthemfrombeingmisinterpretedas
metacharacters.
1.2.10 VerifythattheapplicationisprotectedagainstCSVandFormulaInjection. 3
TheapplicationmustfollowtheescapingrulesdefinedinRFC4180sections
2.6and2.7whenexportingCSVcontent. Additionally,whenexportingtoCSV
orotherspreadsheetformats(suchasXLS,XLSX,orODF),specialcharacters
(including‘=’,‘+’,‘‑’,‘@’,‘\t’(tab),and‘\0’(nullcharacter))mustbeescaped
withasinglequoteiftheyappearasthefirstcharacterinafieldvalue.
Note: UsingparameterizedqueriesorescapingSQLisnotalwayssufficient. Querypartssuchastable
and column names (including “ORDER BY”column names) cannot be escaped. Including escaped
user‑supplieddatainthesefieldsresultsinfailedqueriesorSQLinjection.
25

ApplicationSecurityVerificationStandard May2025
V1.3Sanitization
Theidealprotectionagainstusinguntrustedcontentinanunsafecontextistousecontext‑specific
encodingorescaping,whichmaintainsthesamesemanticmeaningoftheunsafecontentbutrenders
itsafeforuseinthatparticularcontext,asdiscussedinmoredetailintheprevioussection.
Wherethisisnotpossible,sanitizationbecomesnecessary,removingpotentiallydangerouscharac‑
tersorcontent. Insomecases,thismaychangethesemanticmeaningoftheinput,butforsecurity
reasons,theremaybenoalternative.
# Description Level
1.3.1 VerifythatalluntrustedHTMLinputfromWYSIWYGeditorsorsimilaris 1
sanitizedusingawell‑knownandsecureHTMLsanitizationlibraryor
frameworkfeature.
1.3.2 Verifythattheapplicationavoidstheuseofeval()orotherdynamiccode 1
executionfeaturessuchasSpringExpressionLanguage(SpEL).Wherethere
isnoalternative,anyuserinputbeingincludedmustbesanitizedbefore
beingexecuted.
1.3.3 Verifythatdatabeingpassedtoapotentiallydangerouscontextissanitized 2
beforehandtoenforcesafetymeasures,suchasonlyallowingcharacters
whicharesafeforthiscontextandtrimminginputwhichistoolong.
1.3.4 Verifythatuser‑suppliedScalableVectorGraphics(SVG)scriptablecontentis 2
validatedorsanitizedtocontainonlytagsandattributes(suchasdraw
graphics)thataresafefortheapplication,e.g.,donotcontainscriptsand
foreignObject.
1.3.5 Verifythattheapplicationsanitizesordisablesuser‑suppliedscriptableor 2
expressiontemplatelanguagecontent,suchasMarkdown,CSSorXSL
stylesheets,BBCode,orsimilar.
1.3.6 VerifythattheapplicationprotectsagainstServer‑sideRequestForgery 2
(SSRF)attacks,byvalidatinguntrusteddataagainstanallowlistofprotocols,
domains,pathsandportsandsanitizingpotentiallydangerouscharacters
beforeusingthedatatocallanotherservice.
1.3.7 Verifythattheapplicationprotectsagainsttemplateinjectionattacksbynot 2
allowingtemplatestobebuiltbasedonuntrustedinput. Wherethereisno
alternative,anyuntrustedinputbeingincludeddynamicallyduringtemplate
creationmustbesanitizedorstrictlyvalidated.
1.3.8 Verifythattheapplicationappropriatelysanitizesuntrustedinputbeforeuse 2
inJavaNamingandDirectoryInterface(JNDI)queriesandthatJNDIis
configuredsecurelytopreventJNDIinjectionattacks.
26

ApplicationSecurityVerificationStandard May2025
# Description Level
1.3.9 Verifythattheapplicationsanitizescontentbeforeitissenttomemcacheto 2
preventinjectionattacks.
1.3.10 Verifythatformatstringswhichmightresolveinanunexpectedormalicious 2
waywhenusedaresanitizedbeforebeingprocessed.
1.3.11 Verifythattheapplicationsanitizesuserinputbeforepassingtomail 2
systemstoprotectagainstSMTPorIMAPinjection.
1.3.12 Verifythatregularexpressionsarefreefromelementscausingexponential 3
backtracking,andensureuntrustedinputissanitizedtomitigateReDoSor
RunawayRegexattacks.
V1.4Memory,String,andUnmanagedCode
Thefollowingrequirementsaddressrisksassociatedwithunsafememoryuse,whichgenerallyapply
whentheapplicationusesasystemslanguageorunmanagedcode.
Insomecases,itmaybepossibletoachievethisbysettingcompilerflagsthatenablebufferoverflow
protections and warnings, including stack randomization and data execution prevention, and that
breakthebuildifunsafepointer,memory,formatstring,integer,orstringoperationsarefound.
# Description Level
1.4.1 Verifythattheapplicationusesmemory‑safestring,safermemorycopyand 2
pointerarithmetictodetectorpreventstack,buffer,orheapoverflows.
1.4.2 Verifythatsign,range,andinputvalidationtechniquesareusedtoprevent 2
integeroverflows.
1.4.3 Verifythatdynamicallyallocatedmemoryandresourcesarereleased,and 2
thatreferencesorpointerstofreedmemoryareremovedorsettonullto
preventdanglingpointersanduse‑after‑freevulnerabilities.
V1.5SafeDeserialization
The conversion of data from a stored or transmitted representation into actual application objects
(deserialization)hashistoricallybeenthecauseofvariouscodeinjectionvulnerabilities. Itisimpor‑
tanttoperformthisprocesscarefullyandsafelytoavoidthesetypesofissues.
Inparticular,certainmethodsofdeserializationhavebeenidentifiedbyprogramminglanguageor
frameworkdocumentationasinsecureandcannotbemadesafewithuntrusteddata. Foreachmech‑
anisminuse,carefulduediligenceshouldbeperformed.
27

ApplicationSecurityVerificationStandard May2025
# Description Level
1.5.1 VerifythattheapplicationconfiguresXMLparserstousearestrictive 1
configurationandthatunsafefeaturessuchasresolvingexternalentitiesare
disabledtopreventXMLeXternalEntity(XXE)attacks.
1.5.2 Verifythatdeserializationofuntrusteddataenforcessafeinputhandling, 2
suchasusinganallowlistofobjecttypesorrestrictingclient‑definedobject
types,topreventdeserializationattacks. Deserializationmechanismsthat
areexplicitlydefinedasinsecuremustnotbeusedwithuntrustedinput.
1.5.3 Verifythatdifferentparsersusedintheapplicationforthesamedatatype 3
(e.g.,JSONparsers,XMLparsers,URLparsers),performparsingina
consistentwayandusethesamecharacterencodingmechanismtoavoid
issuessuchasJSONInteroperabilityvulnerabilitiesordifferentURIorfile
parsingbehaviorbeingexploitedinRemoteFileInclusion(RFI)or
Server‑sideRequestForgery(SSRF)attacks.
References
Formoreinformation,seealso:
• OWASPLDAPInjectionPreventionCheatSheet
• OWASPCrossSiteScriptingPreventionCheatSheet
• OWASPDOMBasedCrossSiteScriptingPreventionCheatSheet
• OWASPXMLExternalEntityPreventionCheatSheet
• OWASPWebSecurityTestingGuide: Client‑SideTesting
• OWASPJavaEncodingProject
• DOMPurify‑Client‑sideHTMLSanitizationLibrary
• RFC4180‑CommonFormatandMIMETypeforComma‑SeparatedValues(CSV)Files
Formoreinformation,specificallyondeserializationorparsingissues,pleasesee:
• OWASPDeserializationCheatSheet
• AnExplorationofJSONInteroperabilityVulnerabilities
• OrangeTsai‑ANewEraofSSRFExploitingURLParserInTrendingProgrammingLanguages
V2ValidationandBusinessLogic
ControlObjective
Thischapteraimstoensurethataverifiedapplicationmeetsthefollowinghigh‑levelgoals:
28

ApplicationSecurityVerificationStandard May2025
• Inputreceivedbytheapplicationmatchesbusinessorfunctionalexpectations.
• Thebusinesslogicflowissequential,processedinorder,andcannotbebypassed.
• Business logic includes limits and controls to detect and prevent automated attacks, such as
continuoussmallfundstransfersoraddingamillionfriendsoneatatime.
• High‑value business logic flows have considered abuse cases and malicious actors, and have
protectionsagainstspoofing,tampering,informationdisclosure,andelevationofprivilegeat‑
tacks.
V2.1ValidationandBusinessLogicDocumentation
Validation and business logic documentation should clearlydefine business logic limits, validation
rules,andcontextualconsistencyofcombineddataitems,soitisclearwhatneedstobeimplemented
intheapplication.
# Description Level
2.1.1 Verifythattheapplication’sdocumentationdefinesinputvalidationrulesfor 1
howtocheckthevalidityofdataitemsagainstanexpectedstructure. This
couldbecommondataformatssuchascreditcardnumbers,email
addresses,telephonenumbers,oritcouldbeaninternaldataformat.
2.1.2 Verifythattheapplication’sdocumentationdefineshowtovalidatethe 2
logicalandcontextualconsistencyofcombineddataitems,suchaschecking
thatsuburbandZIPcodematch.
2.1.3 Verifythatexpectationsforbusinesslogiclimitsandvalidationsare 2
documented,includingbothper‑userandgloballyacrosstheapplication.
V2.2InputValidation
Effective input validation controls enforce business or functional expectations around the type of
data the application expects to receive. This ensures good data quality and reduces the attack sur‑
face. However,itdoesnotremoveorreplacetheneedtousecorrectencoding,parameterization,or
sanitizationwhenusingthedatainanothercomponentorforpresentingitforoutput.
Inthiscontext,“input”couldcomefromawidevarietyofsources,includingHTMLformfields,REST
requests,URLparameters,HTTPheaderfields,cookies,filesondisk,databases,andexternalAPIs.
Abusinesslogiccontrolmightcheckthataparticularinputisanumberlessthan100. Afunctional
expectation might check that a number is below a certain threshold, as that number controls how
manytimesaparticularloopwilltakeplace,andahighnumbercouldleadtoexcessiveprocessing
andapotentialdenialofservicecondition.
29

ApplicationSecurityVerificationStandard May2025
Whileschemavalidationisnotexplicitlymandated,itmaybethemosteffectivemechanismforfull
validationcoverageofHTTPAPIsorotherinterfacesthatuseJSONorXML.
PleasenotethefollowingpointsonSchemaValidation:
• The“publishedversion”oftheJSONSchemavalidationspecificationisconsideredproduction‑
ready,butnotstrictlyspeaking“stable.”WhenusingJSONSchemavalidation,ensurethereare
nogapswiththeguidanceintherequirementsbelow.
• AnyJSONSchemavalidationlibrariesinuseshouldalsobemonitoredandupdatedifnecessary
oncethestandardisformalized.
• DTDvalidationshouldnotbeused,andframeworkDTDevaluationshouldbedisabled,toavoid
issueswithXXEattacksagainstDTDs.
# Description Level
2.2.1 Verifythatinputisvalidatedtoenforcebusinessorfunctionalexpectations 1
forthatinput. Thisshouldeitherusepositivevalidationagainstanallowlist
ofvalues,patterns,andranges,orbebasedoncomparingtheinputtoan
expectedstructureandlogicallimitsaccordingtopredefinedrules. ForL1,
thiscanfocusoninputwhichisusedtomakespecificbusinessorsecurity
decisions. ForL2andup,thisshouldapplytoallinput.
2.2.2 Verifythattheapplicationisdesignedtoenforceinputvalidationatatrusted 1
servicelayer. Whileclient‑sidevalidationimprovesusabilityandshouldbe
encouraged,itmustnotberelieduponasasecuritycontrol.
2.2.3 Verifythattheapplicationensuresthatcombinationsofrelateddataitems 2
arereasonableaccordingtothepre‑definedrules.
V2.3BusinessLogicSecurity
Thissectionconsiderskeyrequirementstoensurethattheapplicationenforcesbusinesslogicpro‑
cessesinthecorrectwayandisnotvulnerabletoattacksthatexploitthelogicandflowoftheappli‑
cation.
# Description Level
2.3.1 Verifythattheapplicationwillonlyprocessbusinesslogicflowsforthesame 1
userintheexpectedsequentialsteporderandwithoutskippingsteps.
2.3.2 Verifythatbusinesslogiclimitsareimplementedpertheapplication’s 2
documentationtoavoidbusinesslogicflawsbeingexploited.
30

ApplicationSecurityVerificationStandard May2025
# Description Level
2.3.3 Verifythattransactionsarebeingusedatthebusinesslogiclevelsuchthat 2
eitherabusinesslogicoperationsucceedsinitsentiretyoritisrolledbackto
thepreviouscorrectstate.
2.3.4 Verifythatbusinesslogiclevellockingmechanismsareusedtoensurethat 2
limitedquantityresources(suchastheaterseatsordeliveryslots)cannotbe
double‑bookedbymanipulatingtheapplication’slogic.
2.3.5 Verifythathigh‑valuebusinesslogicflowsrequiremulti‑userapprovalto 3
preventunauthorizedoraccidentalactions. Thiscouldincludebutisnot
limitedtolargemonetarytransfers,contractapprovals,accesstoclassified
information,orsafetyoverridesinmanufacturing.
V2.4Anti‑automation
Thissectionincludesanti‑automationcontrolstoensurethathuman‑likeinteractionsarerequired
andexcessiveautomatedrequestsareprevented.
# Description Level
2.4.1 Verifythatanti‑automationcontrolsareinplacetoprotectagainstexcessive 2
callstoapplicationfunctionsthatcouldleadtodataexfiltration,
garbage‑datacreation,quotaexhaustion,rate‑limitbreaches,
denial‑of‑service,oroveruseofcostlyresources.
2.4.2 Verifythatbusinesslogicflowsrequirerealistichumantiming,preventing 3
excessivelyrapidtransactionsubmissions.
References
Formoreinformation,seealso:
• OWASPWebSecurityTestingGuide: InputValidationTesting
• OWASPWebSecurityTestingGuide: BusinessLogicTesting
• Anti‑automation can be achieved in many ways, including the use of the OWASP Automated
ThreatstoWebApplications
• OWASPInputValidationCheatSheet
• JSONSchema
31

ApplicationSecurityVerificationStandard May2025
V3WebFrontendSecurity
ControlObjective
Thiscategoryfocusesonrequirementsdesignedtoprotectagainstattacksexecutedviaawebfron‑
tend. Theserequirementsdonotapplytomachine‑to‑machinesolutions.
V3.1WebFrontendSecurityDocumentation
Thissectionoutlinesthebrowsersecurityfeaturesthatshouldbespecifiedintheapplication’sdoc‑
umentation.
# Description Level
3.1.1 Verifythatapplicationdocumentationstatestheexpectedsecurityfeatures 3
thatbrowsersusingtheapplicationmustsupport(suchasHTTPS,HTTP
StrictTransportSecurity(HSTS),ContentSecurityPolicy(CSP),andother
relevantHTTPsecuritymechanisms). Itmustalsodefinehowthe
applicationmustbehavewhensomeofthesefeaturesarenotavailable(such
aswarningtheuserorblockingaccess).
V3.2UnintendedContentInterpretation
Renderingcontentorfunctionalityinanincorrectcontextcanresultinmaliciouscontentbeingex‑
ecutedordisplayed.
# Description Level
3.2.1 Verifythatsecuritycontrolsareinplacetopreventbrowsersfromrendering 1
contentorfunctionalityinHTTPresponsesinanincorrectcontext(e.g.,
whenanAPI,auser‑uploadedfileorotherresourceisrequesteddirectly).
Possiblecontrolscouldinclude: notservingthecontentunlessHTTPrequest
headerfields(suchasSec‑Fetch‑*)indicateitisthecorrectcontext,usingthe
sandboxdirectiveoftheContent‑Security‑Policyheaderfieldorusingthe
attachmentdispositiontypeintheContent‑Dispositionheaderfield.
3.2.2 Verifythatcontentintendedtobedisplayedastext,ratherthanrenderedas 1
HTML,ishandledusingsaferenderingfunctions(suchascreateTextNodeor
textContent)topreventunintendedexecutionofcontentsuchasHTMLor
JavaScript.
32

ApplicationSecurityVerificationStandard May2025
# Description Level
3.2.3 VerifythattheapplicationavoidsDOMclobberingwhenusingclient‑side 3
JavaScriptbyemployingexplicitvariabledeclarations,performingstricttype
checking,avoidingstoringglobalvariablesonthedocumentobject,and
implementingnamespaceisolation.
V3.3CookieSetup
This section outlines requirements for securely configuring sensitive cookies to provide a higher
levelofassurancethattheywerecreatedbytheapplicationitselfandtopreventtheircontentsfrom
leakingorbeinginappropriatelymodified.
# Description Level
3.3.1 Verifythatcookieshavethe‘Secure’attributeset,andifthe’__Host‑’prefixis 1
notusedforthecookiename,the’__Secure‑’prefixmustbeusedforthe
cookiename.
3.3.2 Verifythateachcookie’s‘SameSite’attributevalueissetaccordingtothe 2
purposeofthecookie,tolimitexposuretouserinterfaceredressattacksand
browser‑basedrequestforgeryattacks,commonlyknownascross‑site
requestforgery(CSRF).
3.3.3 Verifythatcookieshavethe’__Host‑’prefixforthecookienameunlessthey 2
areexplicitlydesignedtobesharedwithotherhosts.
3.3.4 Verifythatifthevalueofacookieisnotmeanttobeaccessibletoclient‑side 2
scripts(suchasasessiontoken),thecookiemusthavethe‘HttpOnly’
attributesetandthesamevalue(e. g. sessiontoken)mustonlybe
transferredtotheclientviathe‘Set‑Cookie’headerfield.
3.3.5 Verifythatwhentheapplicationwritesacookie,thecookienameandvalue 3
lengthcombinedarenotover4096bytes. Overlylargecookieswillnotbe
storedbythebrowserandthereforenotsentwithrequests,preventingthe
userfromusingapplicationfunctionalitywhichreliesonthatcookie.
V3.4BrowserSecurityMechanismHeaders
Thissectiondescribes whichsecurity headersshouldbeset onHTTPresponsestoenablebrowser
securityfeaturesandrestrictionswhenhandlingresponsesfromtheapplication.
33

ApplicationSecurityVerificationStandard May2025
# Description Level
3.4.1 VerifythataStrict‑Transport‑Securityheaderfieldisincludedonall 1
responsestoenforceanHTTPStrictTransportSecurity(HSTS)policy. A
maximumageofatleast1yearmustbedefined,andforL2andup,the
policymustapplytoallsubdomainsaswell.
3.4.2 VerifythattheCross‑OriginResourceSharing(CORS) 1
Access‑Control‑Allow‑Originheaderfieldisafixedvaluebytheapplication,
oriftheOriginHTTPrequestheaderfieldvalueisused,itisvalidatedagainst
anallowlistoftrustedorigins. When’Access‑Control‑Allow‑Origin: *’needs
tobeused,verifythattheresponsedoesnotincludeanysensitive
information.
3.4.3 VerifythatHTTPresponsesincludeaContent‑Security‑Policyresponse 2
headerfieldwhichdefinesdirectivestoensurethebrowseronlyloadsand
executestrustedcontentorresources,inordertolimitexecutionof
maliciousJavaScript. Asaminimum,aglobalpolicymustbeusedwhich
includesthedirectivesobject‑src‘none’andbase‑uri‘none’anddefineseither
anallowlistorusesnoncesorhashes. ForanL3application,aper‑response
policywithnoncesorhashesmustbedefined.
3.4.4 VerifythatallHTTPresponsescontainan‘X‑Content‑Type‑Options: nosniff’ 2
headerfield. ThisinstructsbrowsersnottousecontentsniffingandMIME
typeguessingforthegivenresponse,andtorequiretheresponse’s
Content‑Typeheaderfieldvaluetomatchthedestinationresource. For
example,theresponsetoarequestforastyleisonlyacceptedifthe
response’sContent‑Typeis‘text/css’. Thisalsoenablestheuseofthe
Cross‑OriginReadBlocking(CORB)functionalitybythebrowser.
3.4.5 Verifythattheapplicationsetsareferrerpolicytopreventleakageof 2
technicallysensitivedatatothird‑partyservicesviathe‘Referer’HTTP
requestheaderfield. ThiscanbedoneusingtheReferrer‑PolicyHTTP
responseheaderfieldorviaHTMLelementattributes. Sensitivedatacould
includepathandquerydataintheURL,andforinternalnon‑public
applicationsalsothehostname.
3.4.6 Verifythatthewebapplicationusestheframe‑ancestorsdirectiveofthe 2
Content‑Security‑PolicyheaderfieldforeveryHTTPresponsetoensurethat
itcannotbeembeddedbydefaultandthatembeddingofspecificresources
isallowedonlywhennecessary. NotethattheX‑Frame‑Optionsheaderfield,
althoughsupportedbybrowsers,isobsoleteandmaynotbereliedupon.
3.4.7 VerifythattheContent‑Security‑Policyheaderfieldspecifiesalocationto 3
reportviolations.
34

ApplicationSecurityVerificationStandard May2025
# Description Level
3.4.8 VerifythatallHTTPresponsesthatinitiateadocumentrendering(suchas 3
responseswithContent‑Typetext/html),includethe
Cross‑Origin‑Opener‑Policyheaderfieldwiththesame‑origindirectiveor
thesame‑origin‑allow‑popupsdirectiveasrequired. Thispreventsattacks
thatabusesharedaccesstoWindowobjects,suchastabnabbingandframe
counting.
V3.5BrowserOriginSeparation
Whenacceptingarequesttosensitivefunctionalityontheserverside,theapplicationneedstoensure
therequestisinitiatedbytheapplicationitselforbyatrustedpartyandhasnotbeenforgedbyan
attacker.
Sensitive functionality in this context could include accepting form posts for authenticated
and non‑authenticated users (such as an authentication request), state‑changing operations, or
resource‑demandingfunctionality(suchasdataexport).
The key protections here are browser security policies like Same Origin Policy for JavaScript and
alsoSameSitelogicforcookies. AnothercommonprotectionistheCORSpreflightmechanism. This
mechanismwillbecriticalforendpointsdesignedtobecalledfromadifferentorigin,butitcanalso
beausefulrequestforgerypreventionmechanismforendpointswhicharenotdesignedtobecalled
fromadifferentorigin.
# Description Level
3.5.1 Verifythat,iftheapplicationdoesnotrelyontheCORSpreflightmechanism 1
topreventdisallowedcross‑originrequeststousesensitivefunctionality,
theserequestsarevalidatedtoensuretheyoriginatefromtheapplication
itself. Thismaybedonebyusingandvalidatinganti‑forgerytokensor
requiringextraHTTPheaderfieldsthatarenotCORS‑safelisted
request‑headerfields. Thisistodefendagainstbrowser‑basedrequest
forgeryattacks,commonlyknownascross‑siterequestforgery(CSRF).
3.5.2 Verifythat,iftheapplicationreliesontheCORSpreflightmechanismto 1
preventdisallowedcross‑originuseofsensitivefunctionality,itisnot
possibletocallthefunctionalitywitharequestwhichdoesnottriggera
CORS‑preflightrequest. Thismayrequirecheckingthevaluesofthe‘Origin’
and‘Content‑Type’requestheaderfieldsorusinganextraheaderfieldthatis
notaCORS‑safelistedheader‑field.
35

ApplicationSecurityVerificationStandard May2025
# Description Level
3.5.3 VerifythatHTTPrequeststosensitivefunctionalityuseappropriateHTTP 1
methodssuchasPOST,PUT,PATCH,orDELETE,andnotmethodsdefined
bytheHTTPspecificationas“safe”suchasHEAD,OPTIONS,orGET.
Alternatively,strictvalidationoftheSec‑Fetch‑*requestheaderfieldscanbe
usedtoensurethattherequestdidnotoriginatefromaninappropriate
cross‑origincall,anavigationrequest,oraresourceload(suchasanimage
source)wherethisisnotexpected.
3.5.4 Verifythatseparateapplicationsarehostedondifferenthostnamesto 2
leveragetherestrictionsprovidedbysame‑originpolicy,includinghow
documentsorscriptsloadedbyoneorigincaninteractwithresourcesfrom
anotheroriginandhostname‑basedrestrictionsoncookies.
3.5.5 VerifythatmessagesreceivedbythepostMessageinterfacearediscardedif 2
theoriginofthemessageisnottrusted,orifthesyntaxofthemessageis
invalid.
3.5.6 VerifythatJSONPfunctionalityisnotenabledanywhereacrossthe 3
applicationtoavoidCross‑SiteScriptInclusion(XSSI)attacks.
3.5.7 Verifythatdatarequiringauthorizationisnotincludedinscriptresource 3
responses,likeJavaScriptfiles,topreventCross‑SiteScriptInclusion(XSSI)
attacks.
3.5.8 Verifythatauthenticatedresources(suchasimages,videos,scripts,and 3
otherdocuments)canbeloadedorembeddedonbehalfoftheuseronly
whenintended. Thiscanbeaccomplishedbystrictvalidationofthe
Sec‑Fetch‑*HTTPrequestheaderfieldstoensurethattherequestdidnot
originatefromaninappropriatecross‑origincall,orbysettingarestrictive
Cross‑Origin‑Resource‑PolicyHTTPresponseheaderfieldtoinstructthe
browsertoblockreturnedcontent.
V3.6ExternalResourceIntegrity
Thissectionprovidesguidanceforthesafehostingofcontentonthird‑partysites.
36

ApplicationSecurityVerificationStandard May2025
# Description Level
3.6.1 Verifythatclient‑sideassets,suchasJavaScriptlibraries,CSS,orwebfonts, 3
areonlyhostedexternally(e.g.,onaContentDeliveryNetwork)ifthe
resourceisstaticandversionedandSubresourceIntegrity(SRI)isusedto
validatetheintegrityoftheasset. Ifthisisnotpossible,thereshouldbea
documentedsecuritydecisiontojustifythisforeachresource.
V3.7OtherBrowserSecurityConsiderations
Thissectionincludesvariousothersecuritycontrolsandmodernbrowsersecurityfeaturesrequired
forclient‑sidebrowsersecurity.
# Description Level
3.7.1 Verifythattheapplicationonlyusesclient‑sidetechnologieswhicharestill 2
supportedandconsideredsecure. Examplesoftechnologieswhichdonot
meetthisrequirementincludeNSAPIplugins,Flash,Shockwave,ActiveX,
Silverlight,NACL,orclient‑sideJavaapplets.
3.7.2 Verifythattheapplicationwillonlyautomaticallyredirecttheusertoa 2
differenthostnameordomain(whichisnotcontrolledbytheapplication)
wherethedestinationappearsonanallowlist.
3.7.3 Verifythattheapplicationshowsanotificationwhentheuserisbeing 3
redirectedtoaURLoutsideoftheapplication’scontrol,withanoptionto
cancelthenavigation.
3.7.4 Verifythattheapplication’stop‑leveldomain(e.g.,site.tld)isaddedtothe 3
publicpreloadlistforHTTPStrictTransportSecurity(HSTS).Thisensures
thattheuseofTLSfortheapplicationisbuiltdirectlyintothemain
browsers,ratherthanrelyingonlyontheStrict‑Transport‑Securityresponse
headerfield.
3.7.5 Verifythattheapplicationbehavesasdocumented(suchaswarningtheuser 3
orblockingaccess)ifthebrowserusedtoaccesstheapplicationdoesnot
supporttheexpectedsecurityfeatures.
References
Formoreinformation,seealso:
• Set‑Cookie__Host‑prefixdetails
37

ApplicationSecurityVerificationStandard May2025
• OWASPContentSecurityPolicyCheatSheet
• OWASPSecureHeadersProject
• OWASPCross‑SiteRequestForgeryPreventionCheatSheet
• HSTSBrowserPreloadListsubmissionform
• OWASPDOMClobberingPreventionCheatSheet
V4APIandWebService
ControlObjective
Several considerations apply specifically to applications that expose APIs for use by web browsers
or other consumers (commonly using JSON, XML, or GraphQL). This chapter covers the relevant
securityconfigurationsandmechanismsthatshouldbeapplied.
Notethatauthentication, sessionmanagement, andinputvalidationconcernsfromotherchapters
alsoapplytoAPIs,sothischaptercannotbetakenoutofcontextortestedinisolation.
V4.1GenericWebServiceSecurity
This section addresses general web service security considerations and, consequently, basic web
servicehygienepractices.
# Description Level
4.1.1 VerifythateveryHTTPresponsewithamessagebodycontainsa 1
Content‑Typeheaderfieldthatmatchestheactualcontentoftheresponse,
includingthecharsetparametertospecifysafecharacterencoding(e.g.,
UTF‑8,ISO‑8859‑1)accordingtoIANAMediaTypes,suchas“text/”,“/+xml”
and“/xml”.
4.1.2 Verifythatonlyuser‑facingendpoints(intendedformanualweb‑browser 2
access)automaticallyredirectfromHTTPtoHTTPS,whileotherservicesor
endpointsdonotimplementtransparentredirects. Thisistoavoida
situationwhereaclientiserroneouslysendingunencryptedHTTPrequests,
butsincetherequestsarebeingautomaticallyredirectedtoHTTPS,the
leakageofsensitivedatagoesundiscovered.
4.1.3 VerifythatanyHTTPheaderfieldusedbytheapplicationandsetbyan 2
intermediarylayer,suchasaloadbalancer,awebproxy,ora
backend‑for‑frontendservice,cannotbeoverriddenbytheend‑user.
ExampleheadersmightincludeX‑Real‑IP,X‑Forwarded‑*,orX‑User‑ID.
38

ApplicationSecurityVerificationStandard May2025
# Description Level
4.1.4 VerifythatonlyHTTPmethodsthatareexplicitlysupportedbythe 3
applicationoritsAPI(includingOPTIONSduringpreflightrequests)canbe
usedandthatunusedmethodsareblocked.
4.1.5 Verifythatper‑messagedigitalsignaturesareusedtoprovideadditional 3
assuranceontopoftransportprotectionsforrequestsortransactionswhich
arehighlysensitiveorwhichtraverseanumberofsystems.
V4.2HTTPMessageStructureValidation
ThissectionexplainshowthestructureandheaderfieldsofanHTTPmessageshouldbevalidatedto
preventattackssuchasrequestsmuggling,responsesplitting,headerinjection,anddenialofservice
viaoverlylongHTTPmessages.
TheserequirementsarerelevantforgeneralHTTPmessageprocessingandgeneration, butarees‑
peciallyimportantwhenconvertingHTTPmessagesbetweendifferentHTTPversions.
# Description Level
4.2.1 Verifythatallapplicationcomponents(includingloadbalancers,firewalls, 2
andapplicationservers)determineboundariesofincomingHTTPmessages
usingtheappropriatemechanismfortheHTTPversiontopreventHTTP
requestsmuggling. InHTTP/1.x,ifaTransfer‑Encodingheaderfieldis
present,theContent‑LengthheadermustbeignoredperRFC2616. When
usingHTTP/2orHTTP/3,ifaContent‑Lengthheaderfieldispresent,the
receivermustensurethatitisconsistentwiththelengthoftheDATAframes.
4.2.2 VerifythatwhengeneratingHTTPmessages,theContent‑Lengthheader 3
fielddoesnotconflictwiththelengthofthecontentasdeterminedbythe
framingoftheHTTPprotocol,inordertopreventrequestsmugglingattacks.
4.2.3 VerifythattheapplicationdoesnotsendnoracceptHTTP/2orHTTP/3 3
messageswithconnection‑specificheaderfieldssuchasTransfer‑Encoding
topreventresponsesplittingandheaderinjectionattacks.
4.2.4 VerifythattheapplicationonlyacceptsHTTP/2andHTTP/3requestswhere 3
theheaderfieldsandvaluesdonotcontainanyCR(\r),LF(\n),orCRLF
(\r\n)sequences,topreventheaderinjectionattacks.
39

ApplicationSecurityVerificationStandard May2025
# Description Level
4.2.5 Verifythat,iftheapplication(backendorfrontend)buildsandsends 3
requests,itusesvalidation,sanitization,orothermechanismstoavoid
creatingURIs(suchasforAPIcalls)orHTTPrequestheaderfields(suchas
AuthorizationorCookie),whicharetoolongtobeacceptedbythereceiving
component. Thiscouldcauseadenialofservice,suchaswhensendingan
overlylongrequest(e.g.,alongcookieheaderfield),whichresultsinthe
serveralwaysrespondingwithanerrorstatus.
V4.3GraphQL
GraphQLisbecomingmorecommonasawayofcreatingdata‑richclientsthatarenottightlycoupled
toavarietyofbackendservices. ThissectioncoverssecurityconsiderationsforGraphQL.
# Description Level
4.3.1 Verifythataqueryallowlist,depthlimiting,amountlimiting,orquerycost 2
analysisisusedtopreventGraphQLordatalayerexpressionDenialof
Service(DoS)asaresultofexpensive,nestedqueries.
4.3.2 VerifythatGraphQLintrospectionqueriesaredisabledintheproduction 2
environmentunlesstheGraphQLAPIismeanttobeusedbyotherparties.
V4.4WebSocket
WebSocket is a communications protocol that provides a simultaneous two‑way communication
channel over a single TCP connection. It was standardized by the IETF as RFC 6455 in 2011 and is
distinctfromHTTP,eventhoughitisdesignedtoworkoverHTTPports443and80.
Thissectionprovideskeysecurityrequirementstopreventattacksrelatedtocommunicationsecurity
andsessionmanagementthatspecificallyexploitthisreal‑timecommunicationchannel.
# Description Level
4.4.1 VerifythatWebSocketoverTLS(WSS)isusedforallWebSocketconnections. 1
4.4.2 Verifythat,duringtheinitialHTTPWebSockethandshake,theOriginheader 2
fieldischeckedagainstalistoforiginsallowedfortheapplication.
40

ApplicationSecurityVerificationStandard May2025
# Description Level
4.4.3 Verifythat,iftheapplication’sstandardsessionmanagementcannotbe 2
used,dedicatedtokensarebeingusedforthis,whichcomplywiththe
relevantSessionManagementsecurityrequirements.
4.4.4 VerifythatdedicatedWebSocketsessionmanagementtokensareinitially 2
obtainedorvalidatedthroughthepreviouslyauthenticatedHTTPSsession
whentransitioninganexistingHTTPSsessiontoaWebSocketchannel.
References
Formoreinformation,seealso:
• OWASPRESTSecurityCheatSheet
• ResourcesonGraphQLAuthorizationfromgraphql.organdApollo.
• OWASPWebSecurityTestingGuide: GraphQLTesting
• OWASPWebSecurityTestingGuide: TestingWebSockets
V5FileHandling
ControlObjective
Theuseoffilescanpresentavarietyofriskstotheapplication,includingdenialofservice,unautho‑
rizedaccess,andstorageexhaustion. Thischapterincludesrequirementstoaddresstheserisks.
V5.1FileHandlingDocumentation
Thissectionincludesarequirementtodocumenttheexpectedcharacteristicsoffilesacceptedbythe
application,asanecessarypreconditionfordevelopingandverifyingrelevantsecuritychecks.
# Description Level
5.1.1 Verifythatthedocumentationdefinesthepermittedfiletypes,expectedfile 2
extensions,andmaximumsize(includingunpackedsize)foreachupload
feature. Additionally,ensurethatthedocumentationspecifieshowfilesare
madesafeforend‑userstodownloadandprocess,suchashowthe
applicationbehaveswhenamaliciousfileisdetected.
41

ApplicationSecurityVerificationStandard May2025
V5.2FileUploadandContent
File upload functionality is a primary source of untrusted files. This section outlines the require‑
ments for ensuring that the presence, volume, or content of these files cannot harm the applica‑
tion.
# Description Level
5.2.1 Verifythattheapplicationwillonlyacceptfilesofasizewhichitcanprocess 1
withoutcausingalossofperformanceoradenialofserviceattack.
5.2.2 Verifythatwhentheapplicationacceptsafile,eitheronitsownorwithinan 1
archivesuchasazipfile,itchecksifthefileextensionmatchesanexpected
fileextensionandvalidatesthatthecontentscorrespondtothetype
representedbytheextension. Thisincludes,butisnotlimitedto,checking
theinitial‘magicbytes’,performingimagere‑writing,andusingspecialized
librariesforfilecontentvalidation. ForL1,thiscanfocusjustonfileswhich
areusedtomakespecificbusinessorsecuritydecisions. ForL2andup,this
mustapplytoallfilesbeingaccepted.
5.2.3 Verifythattheapplicationcheckscompressedfiles(e.g.,zip,gz,docx,odt) 2
againstmaximumalloweduncompressedsizeandagainstmaximum
numberoffilesbeforeuncompressingthefile.
5.2.4 Verifythatafilesizequotaandmaximumnumberoffilesperuserare 3
enforcedtoensurethatasingleusercannotfillupthestoragewithtoomany
files,orexcessivelylargefiles.
5.2.5 Verifythattheapplicationdoesnotallowuploadingcompressedfiles 3
containingsymlinksunlessthisisspecificallyrequired(inwhichcaseitwill
benecessarytoenforceanallowlistofthefilesthatcanbesymlinkedto).
5.2.6 Verifythattheapplicationrejectsuploadedimageswithapixelsizelarger 3
thanthemaximumallowed,topreventpixelfloodattacks.
V5.3FileStorage
Thissectionincludesrequirementstopreventfilesfrombeinginappropriatelyexecutedafterupload,
todetectdangerouscontent,andtoavoiduntrusteddatabeingusedtocontrolwherefilesarebeing
stored.
42

ApplicationSecurityVerificationStandard May2025
# Description Level
5.3.1 Verifythatfilesuploadedorgeneratedbyuntrustedinputandstoredina 1
publicfolder,arenotexecutedasserver‑sideprogramcodewhenaccessed
directlywithanHTTPrequest.
5.3.2 Verifythatwhentheapplicationcreatesfilepathsforfileoperations,instead 1
ofuser‑submittedfilenames,itusesinternallygeneratedortrusteddata,orif
user‑submittedfilenamesorfilemetadatamustbeused,strictvalidationand
sanitizationmustbeapplied. Thisistoprotectagainstpathtraversal,localor
remotefileinclusion(LFI,RFI),andserver‑siderequestforgery(SSRF)
attacks.
5.3.3 Verifythatserver‑sidefileprocessing,suchasfiledecompression,ignores 3
user‑providedpathinformationtopreventvulnerabilitiessuchaszipslip.
V5.4FileDownload
Thissectioncontainsrequirementstomitigateriskswhenservingfilestobedownloaded,including
path traversal and injection attacks. This also includes making sure they don’t contain dangerous
content.
# Description Level
5.4.1 Verifythattheapplicationvalidatesorignoresuser‑submittedfilenames, 2
includinginaJSON,JSONP,orURLparameterandspecifiesafilenameinthe
Content‑Dispositionheaderfieldintheresponse.
5.4.2 Verifythatfilenamesserved(e.g.,inHTTPresponseheaderfieldsoremail 2
attachments)areencodedorsanitized(e.g.,followingRFC6266)topreserve
documentstructureandpreventinjectionattacks.
5.4.3 Verifythatfilesobtainedfromuntrustedsourcesarescannedbyantivirus 2
scannerstopreventservingofknownmaliciouscontent.
References
Formoreinformation,seealso:
• OWASPFileUploadCheatSheet
• Exampleofusingsymlinksforarbitraryfileread
• Explanationof“MagicBytes”fromWikipedia
43

ApplicationSecurityVerificationStandard May2025
V6Authentication
ControlObjective
Authenticationistheprocessofestablishingorconfirmingtheauthenticityofanindividualordevice.
Itinvolvesverifyingclaimsmadebyapersonoraboutadevice,ensuringresistancetoimpersonation,
andpreventingtherecoveryorinterceptionofpasswords.
NISTSP800‑63 isamodern, evidence‑based standardthat isvaluablefororganizationsworldwide,
butisparticularlyrelevanttoUSagenciesandthoseinteractingwithUSagencies.
While many of the requirements in this chapter are based on the second section of the standard
(knownasNISTSP800‑63B“DigitalIdentityGuidelines‑AuthenticationandLifecycleManagement”
), the chapter focuses on common threats and frequently exploited authentication weaknesses. It
doesnotattempttocomprehensivelycovereverypointinthestandard. ForcaseswherefullNISTSP
800‑63complianceisnecessary,pleaserefertoNISTSP800‑63.
Additionally, NIST SP 800‑63 terminology may sometimes differ, and this chapter often uses more
commonlyunderstoodterminologytoimproveclarity.
A common feature of more advanced applications is the ability to adapt authentication stages re‑
quired based on various risk factors. This feature is covered in the “Authorization”chapter, since
thesemechanismsalsoneedtobeconsideredforauthorizationdecisions.
V6.1AuthenticationDocumentation
Thissectioncontainsrequirementsdetailingtheauthenticationdocumentationthatshouldbemain‑
tainedforanapplication. Thisiscrucialforimplementingandassessinghowtherelevantauthenti‑
cationcontrolsshouldbeconfigured.
# Description Level
6.1.1 Verifythatapplicationdocumentationdefineshowcontrolssuchasrate 1
limiting,anti‑automation,andadaptiveresponse,areusedtodefendagainst
attackssuchascredentialstuffingandpasswordbruteforce. The
documentationmustmakeclearhowthesecontrolsareconfiguredand
preventmaliciousaccountlockout.
6.1.2 Verifythatalistofcontext‑specificwordsisdocumentedinordertoprevent 2
theiruseinpasswords. Thelistcouldincludepermutationsoforganization
names,productnames,systemidentifiers,projectcodenames,department
orrolenames,andsimilar.
44

ApplicationSecurityVerificationStandard May2025
# Description Level
6.1.3 Verifythat,iftheapplicationincludesmultipleauthenticationpathways, 2
thesearealldocumentedtogetherwiththesecuritycontrolsand
authenticationstrengthwhichmustbeconsistentlyenforcedacrossthem.
V6.2PasswordSecurity
Passwords, called “Memorized Secrets”by NIST SP 800‑63, include passwords, passphrases, PINs,
unlockpatterns, andpickingthecorrectkittenoranotherimageelement. Theyaregenerallycon‑
sidered“somethingyouknow”andareoftenusedasasingle‑factorauthenticationmechanism.
Assuch,thissectioncontainsrequirementsformakingsurethatpasswordsarecreatedandhandled
securely. Most of the requirements are L1 as they are most important at that level. From L2 on‑
wards,multi‑factorauthenticationmechanismsarerequired,wherepasswordsmaybeoneofthose
factors.
Therequirementsinthissectionmostlyrelateto§5.1.1.2ofNIST’sGuidance.
# Description Level
6.2.1 Verifythatusersetpasswordsareatleast8charactersinlengthalthougha 1
minimumof15charactersisstronglyrecommended.
6.2.2 Verifythatuserscanchangetheirpassword. 1
6.2.3 Verifythatpasswordchangefunctionalityrequirestheuser’scurrentand 1
newpassword.
6.2.4 Verifythatpasswordssubmittedduringaccountregistrationorpassword 1
changearecheckedagainstanavailablesetof,atleast,thetop3000
passwordswhichmatchtheapplication’spasswordpolicy,e.g.minimum
length.
6.2.5 Verifythatpasswordsofanycompositioncanbeused,withoutruleslimiting 1
thetypeofcharacterspermitted. Theremustbenorequirementfora
minimumnumberofupperorlowercasecharacters,numbers,orspecial
characters.
6.2.6 Verifythatpasswordinputfieldsusetype=passwordtomasktheentry. 1
Applicationsmayallowtheusertotemporarilyviewtheentiremasked
password,orthelasttypedcharacterofthepassword.
6.2.7 Verifythat“paste”functionality,browserpasswordhelpers,andexternal 1
passwordmanagersarepermitted.
45

ApplicationSecurityVerificationStandard May2025
# Description Level
6.2.8 Verifythattheapplicationverifiestheuser’spasswordexactlyasreceived 1
fromtheuser,withoutanymodificationssuchastruncationorcase
transformation.
6.2.9 Verifythatpasswordsofatleast64charactersarepermitted. 2
6.2.10 Verifythatauser’spasswordstaysvaliduntilitisdiscoveredtobe 2
compromisedortheuserrotatesit. Theapplicationmustnotrequire
periodiccredentialrotation.
6.2.11 Verifythatthedocumentedlistofcontextspecificwordsisusedtoprevent 2
easytoguesspasswordsbeingcreated.
6.2.12 Verifythatpasswordssubmittedduringaccountregistrationorpassword 2
changesarecheckedagainstasetofbreachedpasswords.
V6.3GeneralAuthenticationSecurity
Thissectioncontainsgeneralrequirementsforthesecurityofauthenticationmechanismsaswellas
setting out the different expectations for levels. L2 applications must force the use of multi‑factor
authentication(MFA).L3applicationsmustusehardware‑basedauthentication,performedinanat‑
tested and trusted execution environment (TEE). This could include device‑bound passkeys, eIDAS
LevelofAssurance(LoA)Highenforcedauthenticators,authenticatorswithNISTAuthenticatorAs‑
suranceLevel3(AAL3)assurance,oranequivalentmechanism.
WhilethisisarelativelyaggressivestanceonMFA,itiscriticaltoraisethebararoundthistoprotect
users, andanyattempttorelaxtheserequirementsshouldbeaccompaniedbyaclearplanonhow
therisksaroundauthenticationwillbemitigated,takingintoaccountNIST’sguidanceandresearch
onthetopic.
Notethatatthetimeofrelease,NISTSP800‑63considersemailasnotacceptableasanauthentication
mechanism(archivedcopy).
TherequirementsinthissectionrelatetoavarietyofsectionsofNIST’sGuidance,including: §4.2.1,
§4.3.1,§5.2.2,and§6.1.2.
# Description Level
6.3.1 Verifythatcontrolstopreventattackssuchascredentialstuffingand 1
passwordbruteforceareimplementedaccordingtotheapplication’s
securitydocumentation.
6.3.2 Verifythatdefaultuseraccounts(e.g.,“root”,“admin”,or“sa”)arenot 1
presentintheapplicationoraredisabled.
46

ApplicationSecurityVerificationStandard May2025
# Description Level
6.3.3 Verifythateitheramulti‑factorauthenticationmechanismoracombination 2
ofsingle‑factorauthenticationmechanisms,mustbeusedinordertoaccess
theapplication. ForL3,oneofthefactorsmustbeahardware‑based
authenticationmechanismwhichprovidescompromiseandimpersonation
resistanceagainstphishingattackswhileverifyingtheintenttoauthenticate
byrequiringauser‑initiatedaction(suchasabuttonpressonaFIDO
hardwarekeyoramobilephone). Relaxinganyoftheconsiderationsinthis
requirementrequiresafullydocumentedrationaleandacomprehensiveset
ofmitigatingcontrols.
6.3.4 Verifythat,iftheapplicationincludesmultipleauthenticationpathways, 2
therearenoundocumentedpathwaysandthatsecuritycontrolsand
authenticationstrengthareenforcedconsistently.
6.3.5 Verifythatusersarenotifiedofsuspiciousauthenticationattempts 3
(successfulorunsuccessful). Thismayincludeauthenticationattemptsfrom
anunusuallocationorclient,partiallysuccessfulauthentication(onlyoneof
multiplefactors),anauthenticationattemptafteralongperiodofinactivity
orasuccessfulauthenticationafterseveralunsuccessfulattempts.
6.3.6 Verifythatemailisnotusedaseitherasingle‑factorormulti‑factor 3
authenticationmechanism.
6.3.7 Verifythatusersarenotifiedafterupdatestoauthenticationdetails,suchas 3
credentialresetsormodificationoftheusernameoremailaddress.
6.3.8 Verifythatvaliduserscannotbededucedfromfailedauthentication 3
challenges,suchasbybasingonerrormessages,HTTPresponsecodes,or
differentresponsetimes. Registrationandforgotpasswordfunctionality
mustalsohavethisprotection.
V6.4AuthenticationFactorLifecycleandRecovery
Authenticationfactorsmayincludepasswords,softtokens,hardwaretokens,andbiometricdevices.
Securelyhandlingthelifecycleofthesemechanismsiscriticaltothesecurityofanapplication,and
thissectionincludesrequirementsrelatedtothis.
Therequirementsinthissectionmostlyrelateto§5.1.1.2or§6.1.2.3ofNIST’sGuidance.
47

ApplicationSecurityVerificationStandard May2025
# Description Level
6.4.1 Verifythatsystemgeneratedinitialpasswordsoractivationcodesare 1
securelyrandomlygenerated,followtheexistingpasswordpolicy,and
expireafterashortperiodoftimeoraftertheyareinitiallyused. These
initialsecretsmustnotbepermittedtobecomethelongtermpassword.
6.4.2 Verifythatpasswordhintsorknowledge‑basedauthentication(so‑called 1
“secretquestions”)arenotpresent.
6.4.3 Verifythatasecureprocessforresettingaforgottenpasswordis 2
implemented,thatdoesnotbypassanyenabledmulti‑factorauthentication
mechanisms.
6.4.4 Verifythatifamulti‑factorauthenticationfactorislost,evidenceofidentity 2
proofingisperformedatthesamelevelasduringenrollment.
6.4.5 Verifythatrenewalinstructionsforauthenticationmechanismswhichexpire 3
aresentwithenoughtimetobecarriedoutbeforetheoldauthentication
mechanismexpires,configuringautomatedremindersifnecessary.
6.4.6 Verifythatadministrativeuserscaninitiatethepasswordresetprocessfor 3
theuser,butthatthisdoesnotallowthemtochangeorchoosetheuser’s
password. Thispreventsasituationwheretheyknowtheuser’spassword.
V6.5GeneralMulti‑factorauthenticationrequirements
Thissectionprovidesgeneralguidancethatwillberelevanttovariousdifferentmulti‑factorauthen‑
ticationmethods.
Themechanismsinclude:
• LookupSecrets
• TimebasedOne‑timePasswords(TOTPs)
• Out‑of‑Bandmechanisms
Lookup secrets are pre‑generated lists of secret codes, similar to Transaction Authorization Num‑
bers (TAN), social media recovery codes, or a grid containing a set of random values. This type of
authentication mechanism is considered “something you have”because the codes are deliberately
notmemorablesowillneedtobestoredsomewhere.
Time based One‑time Passwords (TOTPs) are physical or soft tokens that display a continually
changingpseudo‑randomone‑timechallenge. Thistypeofauthenticationmechanismisconsidered
“something you have”. Multi‑factor TOTPs are similar to single‑factor TOTPs, but require a valid
PIN code, biometric unlocking, USB insertion or NFC pairing, or some additional value (such as
transactionsigningcalculators)tobeenteredtocreatethefinalOne‑timePassword(OTP).
48

ApplicationSecurityVerificationStandard May2025
Detailsonout‑of‑bandmechanismswillbeprovidedinthenextsection.
Therequirementsinthesesectionsmostlyrelateto§5.1.2,§5.1.3,§5.1.4.2,§5.1.5.2,§5.2.1,and§
5.2.3ofNIST’sGuidance.
# Description Level
6.5.1 Verifythatlookupsecrets,out‑of‑bandauthenticationrequestsorcodes,and 2
time‑basedone‑timepasswords(TOTPs)areonlysuccessfullyusableonce.
6.5.2 Verifythat,whenbeingstoredintheapplication’sbackend,lookupsecrets 2
withlessthan112bitsofentropy(19randomalphanumericcharactersor34
randomdigits)arehashedwithanapprovedpasswordstoragehashing
algorithmthatincorporatesa32‑bitrandomsalt. Astandardhashfunction
canbeusedifthesecrethas112bitsofentropyormore.
6.5.3 Verifythatlookupsecrets,out‑of‑bandauthenticationcode,andtime‑based 2
one‑timepasswordseeds,aregeneratedusingaCryptographicallySecure
PseudorandomNumberGenerator(CSPRNG)toavoidpredictablevalues.
6.5.4 Verifythatlookupsecretsandout‑of‑bandauthenticationcodeshavea 2
minimumof20bitsofentropy(typically4randomalphanumericcharacters
or6randomdigitsissufficient).
6.5.5 Verifythatout‑of‑bandauthenticationrequests,codes,ortokens,aswellas 2
time‑basedone‑timepasswords(TOTPs)haveadefinedlifetime. Outofband
requestsmusthaveamaximumlifetimeof10minutesandforTOTPa
maximumlifetimeof30seconds.
6.5.6 Verifythatanyauthenticationfactor(includingphysicaldevices)canbe 3
revokedincaseoftheftorotherloss.
6.5.7 Verifythatbiometricauthenticationmechanismsareonlyusedassecondary 3
factorstogetherwitheithersomethingyouhaveorsomethingyouknow.
6.5.8 Verifythattime‑basedone‑timepasswords(TOTPs)arecheckedbasedona 3
timesourcefromatrustedserviceandnotfromanuntrustedorclient
providedtime.
V6.6Out‑of‑Bandauthenticationmechanisms
Thisusuallyinvolvestheauthenticationservercommunicatingwithaphysicaldeviceoverasecure
secondarychannel. Forexample,sendingpushnotificationstomobiledevices. Thistypeofauthen‑
ticationmechanismisconsidered“somethingyouhave”.
Unsafe out‑of‑band authentication mechanisms such as e‑mail and VOIP are not permitted. PSTN
and SMS authentication are currently considered to be “restricted”authentication mechanisms by
49

ApplicationSecurityVerificationStandard May2025
NISTandshouldbedeprecatedinfavorofTimebasedOne‑timePasswords(TOTPs),acryptographic
mechanism,orsimilar. NISTSP800‑63B§5.1.3.3recommendsaddressingtherisksofdeviceswap,
SIMchange,numberporting,orotherabnormalbehavior,iftelephoneorSMSout‑of‑bandauthen‑
ticationabsolutelyhastobesupported. WhilethisASVSsectiondoesnotmandatethisasarequire‑
ment,nottakingtheseprecautionsforasensitiveL2apporanL3appshouldbeseenasasignificant
redflag.
NotethatNISThasalsorecentlyprovidedguidancewhichdiscouragestheuseofpushnotifications.
WhilethisASVSsectiondoesnotdoso,itisimportanttobeawareoftherisksof“pushbombing”.
# Description Level
6.6.1 VerifythatauthenticationmechanismsusingthePublicSwitchedTelephone 2
Network(PSTN)todeliverOne‑timePasswords(OTPs)viaphoneorSMSare
offeredonlywhenthephonenumberhaspreviouslybeenvalidated,
alternatestrongermethods(suchasTimebasedOne‑timePasswords)are
alsooffered,andtheserviceprovidesinformationontheirsecurityrisksto
users. ForL3applications,phoneandSMSmustnotbeavailableasoptions.
6.6.2 Verifythatout‑of‑bandauthenticationrequests,codes,ortokensarebound 2
totheoriginalauthenticationrequestforwhichtheyweregeneratedandare
notusableforapreviousorsubsequentone.
6.6.3 Verifythatacodebasedout‑of‑bandauthenticationmechanismisprotected 2
againstbruteforceattacksbyusingratelimiting. Consideralsousingacode
withatleast64bitsofentropy.
6.6.4 Verifythat,wherepushnotificationsareusedformulti‑factor 3
authentication,ratelimitingisusedtopreventpushbombingattacks.
Numbermatchingmayalsomitigatethisrisk.
V6.7Cryptographicauthenticationmechanism
CryptographicauthenticationmechanismsincludesmartcardsorFIDOkeys,wheretheuserhasto
pluginorpairthecryptographicdevicetothecomputertocompleteauthentication. Theauthenti‑
cationserverwillsendachallengenoncetothecryptographicdeviceorsoftware,andthedeviceor
software calculates a response based upon a securely stored cryptographic key. The requirements
in this section provide implementation‑specific guidance for these mechanisms, with guidance on
cryptographicalgorithmsbeingcoveredinthe“Cryptography”chapter.
Wheresharedorsecretkeysareusedforcryptographicauthentication,theseshouldbestoredusing
the same mechanisms as other system secrets, as documented in the “Secret Management”section
inthe“Configuration”chapter.
Therequirementsinthissectionmostlyrelateto§5.1.7.2ofNIST’sGuidance.
50

ApplicationSecurityVerificationStandard May2025
# Description Level
6.7.1 Verifythatthecertificatesusedtoverifycryptographicauthentication 3
assertionsarestoredinawayprotectsthemfrommodification.
6.7.2 Verifythatthechallengenonceisatleast64bitsinlength,andstatistically 3
uniqueoruniqueoverthelifetimeofthecryptographicdevice.
V6.8AuthenticationwithanIdentityProvider
Identity Providers (IdPs) provide federated identity for users. Users will often have more than one
identity with multiple IdPs, such as an enterprise identity using Azure AD, Okta, Ping Identity, or
Google,orconsumeridentityusingFacebook,Twitter,Google,orWeChat,tonamejustafewcom‑
mon alternatives. This list is not an endorsement of these companies or services, but simply an
encouragementfordeveloperstoconsidertherealitythatmanyusershavemanyestablishedidenti‑
ties. Organizationsshouldconsiderintegratingwithexistinguseridentities,aspertheriskprofileof
theIdP’sstrengthofidentityproofing. Forexample,itisunlikelyagovernmentorganizationwould
accept a social media identity as a login for sensitive systems, as it is easy to create fake or throw‑
awayidentities,whereasamobilegamecompanymaywellneedtointegratewithmajorsocialmedia
platformstogrowtheiractiveplayerbase.
Secure use of external identity providers requires careful configuration and verification to prevent
identityspoofingorforgedassertions. Thissectionprovidesrequirementstoaddresstheserisks.
# Description Level
6.8.1 Verifythat,iftheapplicationsupportsmultipleidentityproviders(IdPs),the 2
user’sidentitycannotbespoofedviaanothersupportedidentityprovider
(eg. byusingthesameuseridentifier). Thestandardmitigationwouldbefor
theapplicationtoregisterandidentifytheuserusingacombinationofthe
IdPID(servingasanamespace)andtheuser’sIDintheIdP.
6.8.2 Verifythatthepresenceandintegrityofdigitalsignaturesonauthentication 2
assertions(forexampleonJWTsorSAMLassertions)arealwaysvalidated,
rejectinganyassertionsthatareunsignedorhaveinvalidsignatures.
6.8.3 VerifythatSAMLassertionsareuniquelyprocessedandusedonlyonce 2
withinthevalidityperiodtopreventreplayattacks.
51

ApplicationSecurityVerificationStandard May2025
# Description Level
6.8.4 Verifythat,ifanapplicationusesaseparateIdentityProvider(IdP)and 2
expectsspecificauthenticationstrength,methods,orrecentnessforspecific
functions,theapplicationverifiesthisusingtheinformationreturnedbythe
IdP.Forexample,ifOIDCisused,thismightbeachievedbyvalidatingID
Tokenclaimssuchas‘acr’,‘amr’,and‘auth_time’(ifpresent). IftheIdPdoes
notprovidethisinformation,theapplicationmusthaveadocumented
fallbackapproachthatassumesthattheminimumstrengthauthentication
mechanismwasused(forexample,single‑factorauthenticationusing
usernameandpassword).
References
Formoreinformation,seealso:
• NISTSP800‑63‑DigitalIdentityGuidelines
• NISTSP800‑63B‑AuthenticationandLifecycleManagement
• NISTSP800‑63FAQ
• OWASPWebSecurityTestingGuide: TestingforAuthentication
• OWASPPasswordStorageCheatSheet
• OWASPForgotPasswordCheatSheet
• OWASPChoosingandUsingSecurityQuestionsCheatSheet
• CISAGuidanceon“NumberMatching”
• DetailsontheFIDOAlliance
V7SessionManagement
ControlObjective
Sessionmanagementmechanismsallowapplicationstocorrelateuseranddeviceinteractionsover
time,evenwhenusingstatelesscommunicationprotocols(suchasHTTP).Modernapplicationsmay
use multiple session tokens with distinct characteristics and purposes. A secure session manage‑
mentsystemisonethatpreventsattackersfromobtaining,utilizing,orotherwiseabusingavictim’
ssession. Applicationsmaintainingsessionsmustensurethatthefollowinghigh‑levelsessionman‑
agementrequirementsaremet:
• Sessionsareuniquetoeachindividualandcannotbeguessedorshared.
• Sessionsareinvalidatedwhennolongerrequiredandaretimedoutduringperiodsofinactivity.
52

ApplicationSecurityVerificationStandard May2025
ManyoftherequirementsinthischapterrelatetoselectedNISTSP800‑63DigitalIdentityGuidelines
controls,focusingoncommonthreatsandcommonlyexploitedauthenticationweaknesses.
Notethatrequirementsforspecificimplementationdetailsofcertainsessionmanagementmecha‑
nismscanbefoundelsewhere:
• HTTPCookiesareacommonmechanismforsecuringsessiontokens. Specificsecurityrequire‑
mentsforcookiescanbefoundinthe“WebFrontendSecurity”chapter.
• Self‑contained tokens are frequently used as a way of maintaining sessions. Specific security
requirementscanbefoundinthe“Self‑containedTokens”chapter.
V7.1SessionManagementDocumentation
Thereisnosinglepatternthatsuitsallapplications. Therefore,itisnotfeasibletodefineuniversal
boundariesandlimitsthatsuitallcases. Ariskanalysiswithdocumentedsecuritydecisionsrelated
tosessionhandlingmustbeconductedasaprerequisitetoimplementationandtesting. Thisensures
thatthesessionmanagementsystemistailoredtothespecificrequirementsoftheapplication.
Regardless of whether a stateful or “stateless”session mechanism is chosen, the analysis must be
completeanddocumentedtodemonstratethattheselectedsolutioniscapableofsatisfyingallrel‑
evant security requirements. Interaction with any Single Sign‑on (SSO) mechanisms in use should
alsobeconsidered.
# Description Level
7.1.1 Verifythattheuser’ssessioninactivitytimeoutandabsolutemaximum 2
sessionlifetimearedocumented,areappropriateincombinationwithother
controls,andthatthedocumentationincludesjustificationforany
deviationsfromNISTSP800‑63Bre‑authenticationrequirements.
7.1.2 Verifythatthedocumentationdefineshowmanyconcurrent(parallel) 2
sessionsareallowedforoneaccountaswellastheintendedbehaviorsand
actionstobetakenwhenthemaximumnumberofactivesessionsisreached.
7.1.3 Verifythatallsystemsthatcreateandmanageusersessionsaspartofa 2
federatedidentitymanagementecosystem(suchasSSOsystems)are
documentedalongwithcontrolstocoordinatesessionlifetimes,
termination,andanyotherconditionsthatrequirere‑authentication.
V7.2FundamentalSessionManagementSecurity
Thissectionsatisfiestheessentialrequirementsofsecuresessionsbyverifyingthatsessiontokens
aresecurelygeneratedandvalidated.
53

ApplicationSecurityVerificationStandard May2025
# Description Level
7.2.1 Verifythattheapplicationperformsallsessiontokenverificationusinga 1
trusted,backendservice.
7.2.2 Verifythattheapplicationuseseitherself‑containedorreferencetokensthat 1
aredynamicallygeneratedforsessionmanagement,i.e.notusingstaticAPI
secretsandkeys.
7.2.3 Verifythatifreferencetokensareusedtorepresentusersessions,theyare 1
uniqueandgeneratedusingacryptographicallysecurepseudo‑random
numbergenerator(CSPRNG)andpossessatleast128bitsofentropy.
7.2.4 Verifythattheapplicationgeneratesanewsessiontokenonuser 1
authentication,includingre‑authentication,andterminatesthecurrent
sessiontoken.
V7.3SessionTimeout
Sessiontimeoutmechanismsservetominimizethewindowofopportunityforsessionhijackingand
otherformsofsessionabuse. Timeoutsmustsatisfydocumentedsecuritydecisions.
# Description Level
7.3.1 Verifythatthereisaninactivitytimeoutsuchthatre‑authenticationis 2
enforcedaccordingtoriskanalysisanddocumentedsecuritydecisions.
7.3.2 Verifythatthereisanabsolutemaximumsessionlifetimesuchthat 2
re‑authenticationisenforcedaccordingtoriskanalysisanddocumented
securitydecisions.
V7.4SessionTermination
SessionterminationmaybehandledeitherbytheapplicationitselforbytheSSOprovideriftheSSO
providerishandlingsessionmanagementinsteadoftheapplication. Itmaybenecessarytodecide
whethertheSSOproviderisinscopewhenconsideringtherequirementsinthissectionassomemay
becontrolledbytheprovider.
Sessionterminationshouldresultinrequiringre‑authenticationandbeeffectiveacrosstheapplica‑
tion,federatedlogin(ifpresent),andanyrelyingparties.
Forstatefulsessionmechanisms,terminationtypicallyinvolvesinvalidatingthesessionontheback‑
end. Inthecaseofself‑containedtokens,additionalmeasuresarerequiredtorevokeorblockthese
tokens,astheymayotherwiseremainvaliduntilexpiration.
54

ApplicationSecurityVerificationStandard May2025
# Description Level
7.4.1 Verifythatwhensessionterminationistriggered(suchaslogoutor 1
expiration),theapplicationdisallowsanyfurtheruseofthesession. For
referencetokensorstatefulsessions,thismeansinvalidatingthesession
dataattheapplicationbackend. Applicationsusingself‑containedtokens
willneedasolutionsuchasmaintainingalistofterminatedtokens,
disallowingtokensproducedbeforeaper‑userdateandtimeorrotatinga
per‑usersigningkey.
7.4.2 Verifythattheapplicationterminatesallactivesessionswhenauseraccount 1
isdisabledordeleted(suchasanemployeeleavingthecompany).
7.4.3 Verifythattheapplicationgivestheoptiontoterminateallotheractive 2
sessionsafterasuccessfulchangeorremovalofanyauthenticationfactor
(includingpasswordchangeviaresetorrecoveryand,ifpresent,anMFA
settingsupdate).
7.4.4 Verifythatallpagesthatrequireauthenticationhaveeasyandvisibleaccess 2
tologoutfunctionality.
7.4.5 Verifythatapplicationadministratorsareabletoterminateactivesessions 2
foranindividualuserorforallusers.
V7.5DefensesAgainstSessionAbuse
This section provides requirements to mitigate the risk posed by active sessions that are either hi‑
jackedorabusedthroughvectorsthatrelyontheexistenceandcapabilitiesofactiveusersessions.
Forexample,usingmaliciouscontentexecutiontoforceanauthenticatedvictimbrowsertoperform
anactionusingthevictim’ssession.
Note that the level‑specific guidance in the “Authentication”chapter should be taken into account
whenconsideringrequirementsinthissection.
# Description Level
7.5.1 Verifythattheapplicationrequiresfullre‑authenticationbeforeallowing 2
modificationstosensitiveaccountattributeswhichmayaffect
authenticationsuchasemailaddress,phonenumber,MFAconfiguration,or
otherinformationusedinaccountrecovery.
7.5.2 Verifythatusersareabletoviewand(havingauthenticatedagainwithat 2
leastonefactor)terminateanyorallcurrentlyactivesessions.
55

ApplicationSecurityVerificationStandard May2025
# Description Level
7.5.3 Verifythattheapplicationrequiresfurtherauthenticationwithatleastone 3
factororsecondaryverificationbeforeperforminghighlysensitive
transactionsoroperations.
V7.6FederatedRe‑authentication
This section relates to those writing Relying Party (RP) or Identity Provider (IdP) code. These re‑
quirementsarederivedfromtheNISTSP800‑63CforFederation&Assertions.
# Description Level
7.6.1 VerifythatsessionlifetimeandterminationbetweenRelyingParties(RPs) 2
andIdentityProviders(IdPs)behaveasdocumented,requiring
re‑authenticationasnecessarysuchaswhenthemaximumtimebetween
IdPauthenticationeventsisreached.
7.6.2 Verifythatcreationofasessionrequireseithertheuser’sconsentoran 2
explicitaction,preventingthecreationofnewapplicationsessionswithout
userinteraction.
References
Formoreinformation,seealso:
• OWASPWebSecurityTestingGuide: SessionManagementTesting
• OWASPSessionManagementCheatSheet
V8Authorization
ControlObjective
Authorizationensuresthataccessisgrantedonlytopermittedconsumers(users,servers,andother
clients). ToenforcethePrincipleofLeastPrivilege(POLP),verifiedapplicationsmustmeetthefol‑
lowinghigh‑levelrequirements:
• Documentauthorizationrules,includingdecision‑makingfactorsandenvironmentalcontexts.
• Consumersshouldhaveaccessonlytoresourcespermittedbytheirdefinedentitlements.
56

ApplicationSecurityVerificationStandard May2025
V8.1AuthorizationDocumentation
Comprehensiveauthorizationdocumentationisessentialtoensurethatsecuritydecisionsarecon‑
sistentlyapplied,auditable,andalignedwithorganizationalpolicies. Thisreducestheriskofunau‑
thorized access by making security requirements clear and actionable for developers, administra‑
tors,andtesters.
# Description Level
8.1.1 Verifythatauthorizationdocumentationdefinesrulesforrestricting 1
function‑levelanddata‑specificaccessbasedonconsumerpermissionsand
resourceattributes.
8.1.2 Verifythatauthorizationdocumentationdefinesrulesforfield‑levelaccess 2
restrictions(bothreadandwrite)basedonconsumerpermissionsand
resourceattributes. Notethattheserulesmightdependonotherattribute
valuesoftherelevantdataobject,suchasstateorstatus.
8.1.3 Verifythattheapplication’sdocumentationdefinestheenvironmentaland 3
contextualattributes(includingbutnotlimitedto,timeofday,userlocation,
IPaddress,ordevice)thatareusedintheapplicationtomakesecurity
decisions,includingthosepertainingtoauthenticationandauthorization.
8.1.4 Verifythatauthenticationandauthorizationdocumentationdefineshow 3
environmentalandcontextualfactorsareusedindecision‑making,in
additiontofunction‑level,data‑specific,andfield‑levelauthorization. This
shouldincludetheattributesevaluated,thresholdsforrisk,andactions
taken(e.g.,allow,challenge,deny,step‑upauthentication).
V8.2GeneralAuthorizationDesign
Implementinggranularauthorizationcontrolsatthefunction,data,andfieldlevelsensuresthatcon‑
sumerscanaccessonlywhathasbeenexplicitlygrantedtothem.
# Description Level
8.2.1 Verifythattheapplicationensuresthatfunction‑levelaccessisrestrictedto 1
consumerswithexplicitpermissions.
8.2.2 Verifythattheapplicationensuresthatdata‑specificaccessisrestrictedto 1
consumerswithexplicitpermissionstospecificdataitemstomitigate
insecuredirectobjectreference(IDOR)andbrokenobjectlevel
authorization(BOLA).
57

ApplicationSecurityVerificationStandard May2025
# Description Level
8.2.3 Verifythattheapplicationensuresthatfield‑levelaccessisrestrictedto 2
consumerswithexplicitpermissionstospecificfieldstomitigatebroken
objectpropertylevelauthorization(BOPLA).
8.2.4 Verifythatadaptivesecuritycontrolsbasedonaconsumer’senvironmental 3
andcontextualattributes(suchastimeofday,location,IPaddress,ordevice)
areimplementedforauthenticationandauthorizationdecisions,asdefined
intheapplication’sdocumentation. Thesecontrolsmustbeappliedwhen
theconsumertriestostartanewsessionandalsoduringanexistingsession.
V8.3OperationLevelAuthorization
Theimmediateapplicationofauthorizationchangesintheappropriatetierofanapplication’sarchi‑
tectureiscrucialtopreventingunauthorizedactions,especiallyindynamicenvironments.
# Description Level
8.3.1 Verifythattheapplicationenforcesauthorizationrulesatatrustedservice 1
layeranddoesn’trelyoncontrolsthatanuntrustedconsumercould
manipulate,suchasclient‑sideJavaScript.
8.3.2 Verifythatchangestovaluesonwhichauthorizationdecisionsaremadeare 3
appliedimmediately. Wherechangescannotbeappliedimmediately,(such
aswhenrelyingondatainself‑containedtokens),theremustbemitigating
controlstoalertwhenaconsumerperformsanactionwhentheyareno
longerauthorizedtodosoandrevertthechange. Notethatthisalternative
wouldnotmitigateinformationleakage.
8.3.3 Verifythataccesstoanobjectisbasedontheoriginatingsubject’s 3
(e.g.consumer’s)permissions,notonthepermissionsofanyintermediary
orserviceactingontheirbehalf. Forexample,ifaconsumercallsaweb
serviceusingaself‑containedtokenforauthentication,andtheservicethen
requestsdatafromadifferentservice,thesecondservicewillusethe
consumer’stoken,ratherthanamachine‑to‑machinetokenfromthefirst
service,tomakepermissiondecisions.
V8.4OtherAuthorizationConsiderations
Additional considerations for authorization, particularly for administrative interfaces and multi‑
tenantenvironments,helppreventunauthorizedaccess.
58

ApplicationSecurityVerificationStandard May2025
# Description Level
8.4.1 Verifythatmulti‑tenantapplicationsusecross‑tenantcontrolstoensure 2
consumeroperationswillneveraffecttenantswithwhichtheydonothave
permissionstointeract.
8.4.2 Verifythataccesstoadministrativeinterfacesincorporatesmultiplelayersof 3
security,includingcontinuousconsumeridentityverification,device
securitypostureassessment,andcontextualriskanalysis,ensuringthat
networklocationortrustedendpointsarenotthesolefactorsfor
authorizationeventhoughtheymayreducethelikelihoodofunauthorized
access.
References
Formoreinformation,seealso:
• OWASPWebSecurityTestingGuide: Authorization
• OWASPAuthorizationCheatSheet
V9Self‑containedTokens
ControlObjective
The concept of a self‑contained token is mentioned in the original RFC 6749 OAuth 2.0 from 2012.
Itreferstoatokencontainingdataorclaimsonwhichareceivingservicewillrelytomakesecurity
decisions. Thisshouldbedifferentiatedfromasimpletokencontainingonlyanidentifier, whicha
receivingserviceusestolookupdatalocally. Themostcommonexamplesofself‑containedtokens
areJSONWebTokens(JWTs)andSAMLassertions.
Theuseofself‑containedtokenshasbecomeverywidespread,evenoutsideofOAuthandOIDC.At
the same time, the security of this mechanism relies on the ability to validate the integrity of the
tokenandtoensurethatthetokenisvalidforaparticularcontext. Therearemanypitfallswiththis
process,andthischapterprovidesspecificdetailsofthemechanismsthatapplicationsshouldhave
inplacetopreventthem.
V9.1Tokensourceandintegrity
This section includes requirements to ensure that the token has been produced by a trusted party
andhasnotbeentamperedwith.
59

ApplicationSecurityVerificationStandard May2025
# Description Level
9.1.1 Verifythatself‑containedtokensarevalidatedusingtheirdigitalsignatureor 1
MACtoprotectagainsttamperingbeforeacceptingthetoken’scontents.
9.1.2 Verifythatonlyalgorithmsonanallowlistcanbeusedtocreateandverify 1
self‑containedtokens,foragivencontext. Theallowlistmustincludethe
permittedalgorithms,ideallyonlyeithersymmetricorasymmetric
algorithms,andmustnotincludethe‘None’algorithm. Ifbothsymmetric
andasymmetricmustbesupported,additionalcontrolswillbeneededto
preventkeyconfusion.
9.1.3 Verifythatkeymaterialthatisusedtovalidateself‑containedtokensisfrom 1
trustedpre‑configuredsourcesforthetokenissuer,preventingattackers
fromspecifyinguntrustedsourcesandkeys. ForJWTsandotherJWS
structures,headerssuchas‘jku’,‘x5u’,and‘jwk’mustbevalidatedagainstan
allowlistoftrustedsources.
V9.2Tokencontent
Before making security decisions based on the content of a self‑contained token, it is necessary to
validate that the token has been presented within its validity period and that it is intended for use
by the receiving service and for the purpose for which it was presented. This helps avoid insecure
cross‑usagebetweendifferentservicesorwithdifferenttokentypesfromthesameissuer.
SpecificrequirementsforOAuthandOIDCarecoveredinthededicatedchapter.
# Description Level
9.2.1 Verifythat,ifavaliditytimespanispresentinthetokendata,thetokenand 1
itscontentareacceptedonlyiftheverificationtimeiswithinthisvalidity
timespan. Forexample,forJWTs,theclaims‘nbf’and‘exp’mustbeverified.
9.2.2 Verifythattheservicereceivingatokenvalidatesthetokentobethecorrect 2
typeandismeantfortheintendedpurposebeforeacceptingthetoken’s
contents. Forexample,onlyaccesstokenscanbeacceptedforauthorization
decisionsandonlyIDTokenscanbeusedforprovinguserauthentication.
9.2.3 Verifythattheserviceonlyacceptstokenswhichareintendedforusewith 2
thatservice(audience). ForJWTs,thiscanbeachievedbyvalidatingthe‘aud’
claimagainstanallowlistdefinedintheservice.
60

ApplicationSecurityVerificationStandard May2025
# Description Level
9.2.4 Verifythat,ifatokenissuerusesthesameprivatekeyforissuingtokensto 2
differentaudiences,theissuedtokenscontainanaudiencerestrictionthat
uniquelyidentifiestheintendedaudiences. Thiswillpreventatokenfrom
beingreusedwithanunintendedaudience. Iftheaudienceidentifieris
dynamicallyprovisioned,thetokenissuermustvalidatetheseaudiencesin
ordertomakesurethattheydonotresultinaudienceimpersonation.
References
Formoreinformation,seealso:
• OWASPJSONWebTokenCheatSheetforJavaCheatSheet(buthasusefulgeneralguidance)
V10OAuthandOIDC
ControlObjective
OAuth2(referredtoasOAuthinthischapter)isanindustry‑standardframeworkfordelegatedautho‑
rization. Forexample,usingOAuth,aclientapplicationcanobtainaccesstoAPIs(serverresources)
onauser’sbehalf,providedtheuserhasauthorizedtheclientapplicationtodoso.
By itself, OAuth is not designed for user authentication. The OpenID Connect (OIDC) framework
extendsOAuthbyaddingauseridentitylayerontopofOAuth. OIDCprovidessupportforfeatures
includingstandardizeduserinformation,SingleSign‑On(SSO),andsessionmanagement. AsOIDC
isanextensionofOAuth,theOAuthrequirementsinthischapteralsoapplytoOIDC.
ThefollowingrolesaredefinedinOAuth:
• TheOAuthclientistheapplicationthatattemptstoobtainaccesstoserverresources(e.g.,by
callinganAPIusingtheissuedaccesstoken). TheOAuthclientisoftenaserver‑sideapplication.
– Aconfidentialclientisaclientcapableofmaintainingtheconfidentialityofthecredentials
itusestoauthenticateitselfwiththeauthorizationserver.
– Apublicclientisnotcapableofmaintainingtheconfidentialityofcredentialsforauthen‑
ticating with the authorization server. Therefore, instead of authenticating itself (e.g.,
using ‘client_id’and ‘client_secret’parameters), it only identifies itself (using a ‘client_id’
parameter).
• TheOAuthresourceserver(RS)istheserverAPIexposingresourcestoOAuthclients.
• TheOAuthauthorizationserver(AS)isaserverapplicationthatissuesaccesstokenstoOAuth
clients. TheseaccesstokensallowOAuthclientstoaccessRSresources,eitheronbehalfofan
61

ApplicationSecurityVerificationStandard May2025
end‑user or on the OAuth client’s own behalf. The AS is often a separate application, but (if
appropriate)itmaybeintegratedintoasuitableRS.
• Theresourceowner(RO)istheend‑userwhoauthorizesOAuthclientstoobtainlimitedaccess
to resources hosted on the resource server on their behalf. The resource owner consents to
thisdelegatedauthorizationbyinteractingwiththeauthorizationserver.
ThefollowingrolesaredefinedinOIDC:
• Therelyingparty(RP)istheclientapplicationrequestingend‑userauthenticationthroughthe
OpenIDProvider. ItassumestheroleofanOAuthclient.
• The OpenID Provider (OP) is an OAuth AS that is capable of authenticating the end‑user and
provides OIDC claims to an RP. The OP may be the identity provider (IdP), but in federated
scenarios,theOPandtheidentityprovider(wheretheend‑userauthenticates)maybedifferent
serverapplications.
OAuth and OIDC wereinitially designed forthird‑party applications. Today, they areoften used by
first‑partyapplicationsaswell. However,whenusedinfirst‑partyscenarios,suchasauthentication
and session management, the protocol adds some complexity, which may introduce new security
challenges.
OAuthandOIDCcanbeusedformanytypesofapplications,butthefocusforASVSandtherequire‑
mentsinthischapterisonwebapplicationsandAPIs.
Since OAuth and OIDC can be considered logic on top of web technologies, general requirements
fromotherchaptersalwaysapply,andthischaptercannotbetakenoutofcontext.
ThischapteraddressesbestcurrentpracticesforOAuth2andOIDCalignedwithspecificationsfound
at https://oauth.net/2/ and https://openid.net/developers/specs/. Even if RFCs are considered
mature, they are updated frequently. Thus, it is important to align with the latest versions when
applyingtherequirementsinthischapter. Seethereferencessectionformoredetails.
Given the complexity of the area, it is vitally important for a secure OAuth or OIDC solution to use
well‑knownindustry‑standardauthorizationserversandapplytherecommendedsecurityconfigu‑
ration.
TerminologyusedinthischapteralignswithOAuthRFCsandOIDCspecifications,butnotethatOIDC
terminologyisonlyusedforOIDC‑specificrequirements;otherwise,OAuthterminologyisused.
InthecontextofOAuthandOIDC,theterm“token”inthischapterrefersto:
• Accesstokens,whichshallonlybeconsumedbytheRSandcaneitherbereferencetokensthat
are validated using introspection or self‑contained tokens that are validated using some key
material.
• Refreshtokens,whichshallonlybeconsumedbytheauthorizationserverthatissuedthetoken.
• OIDC ID Tokens, which shall only be consumed by the client that triggered the authorization
flow.
62

ApplicationSecurityVerificationStandard May2025
Therisklevelsforsomeoftherequirementsinthischapterdependonwhethertheclientisaconfi‑
dentialclientorregardedasapublicclient. Sinceusingstrongclientauthenticationmitigatesmany
attackvectors,afewrequirementsmightberelaxedwhenusingaconfidentialclientforL1applica‑
tions.
V10.1GenericOAuthandOIDCSecurity
ThissectioncoversgenericarchitecturalrequirementsthatapplytoallapplicationsusingOAuthor
OIDC.
# Description Level
10.1.1 Verifythattokensareonlysenttocomponentsthatstrictlyneedthem. For 2
example,whenusingabackend‑for‑frontendpatternforbrowser‑based
JavaScriptapplications,accessandrefreshtokensshallonlybeaccessiblefor
thebackend.
10.1.2 Verifythattheclientonlyacceptsvaluesfromtheauthorizationserver(such 2
astheauthorizationcodeorIDToken)ifthesevaluesresultfroman
authorizationflowthatwasinitiatedbythesameuseragentsessionand
transaction. Thisrequiresthatclient‑generatedsecrets,suchastheproof
keyforcodeexchange(PKCE)‘code_verifier’,‘state’orOIDC‘nonce’,arenot
guessable,arespecifictothetransaction,andaresecurelyboundtoboththe
clientandtheuseragentsessioninwhichthetransactionwasstarted.
V10.2OAuthClient
These requirements detail the responsibilities for OAuth client applications. The client can be, for
example, a web server backend (often acting as a Backend For Frontend, BFF), a backend service
integration,orafrontendSinglePageApplication(SPA,akabrowser‑basedapplication).
In general, backend clients are regarded as confidential clients and frontend clients are regarded
as public clients. However, native applications running on the end‑user device can be regarded as
confidentialwhenusingOAuthdynamicclientregistration.
# Description Level
10.2.1 Verifythat,ifthecodeflowisused,theOAuthclienthasprotectionagainst 2
browser‑basedrequestforgeryattacks,commonlyknownascross‑site
requestforgery(CSRF),whichtriggertokenrequests,eitherbyusingproof
keyforcodeexchange(PKCE)functionalityorcheckingthe‘state’parameter
thatwassentintheauthorizationrequest.
63

ApplicationSecurityVerificationStandard May2025
# Description Level
10.2.2 Verifythat,iftheOAuthclientcaninteractwithmorethanoneauthorization 2
server,ithasadefenseagainstmix‑upattacks. Forexample,itcouldrequire
thattheauthorizationserverreturnthe‘iss’parametervalueandvalidateit
intheauthorizationresponseandthetokenresponse.
10.2.3 VerifythattheOAuthclientonlyrequeststherequiredscopes(orother 3
authorizationparameters)inrequeststotheauthorizationserver.
V10.3OAuthResourceServer
InthecontextofASVSandthischapter,theresourceserverisanAPI.Toprovidesecureaccess,the
resourceservermust:
• Validatetheaccesstoken, accordingtothetokenformatandrelevantprotocolspecifications,
e.g.,JWT‑validationorOAuthtokenintrospection.
• Ifvalid, enforceauthorization decisions based on the informationfromthe access tokenand
permissions which have been granted. For example, the resource server needs to verify that
theclient(actingonbehalfofRO)isauthorizedtoaccesstherequestedresource.
Therefore, therequirementslistedhereareOAuthorOIDCspecificandshouldbeperformedafter
tokenvalidationandbeforeperformingauthorizationbasedoninformationfromthetoken.
# Description Level
10.3.1 Verifythattheresourceserveronlyacceptsaccesstokensthatareintended 2
forusewiththatservice(audience). Theaudiencemaybeincludedina
structuredaccesstoken(suchasthe‘aud’claiminJWT),oritcanbechecked
usingthetokenintrospectionendpoint.
10.3.2 Verifythattheresourceserverenforcesauthorizationdecisionsbasedon 2
claimsfromtheaccesstokenthatdefinedelegatedauthorization. Ifclaims
suchas‘sub’,‘scope’,and‘authorization_details’arepresent,theymustbe
partofthedecision.
10.3.3 Verifythatifanaccesscontroldecisionrequiresidentifyingauniqueuser 2
fromanaccesstoken(JWTorrelatedtokenintrospectionresponse),the
resourceserveridentifiestheuserfromclaimsthatcannotbereassignedto
otherusers. Typically,itmeansusingacombinationof‘iss’and‘sub’claims.
64

ApplicationSecurityVerificationStandard May2025
# Description Level
10.3.4 Verifythat,iftheresourceserverrequiresspecificauthenticationstrength, 2
methods,orrecentness,itverifiesthatthepresentedaccesstokensatisfies
theseconstraints. Forexample,ifpresent,usingtheOIDC‘acr’,‘amr’and
‘auth_time’claimsrespectively.
10.3.5 Verifythattheresourceserverpreventstheuseofstolenaccesstokensor 3
replayofaccesstokens(fromunauthorizedparties)byrequiring
sender‑constrainedaccesstokens,eitherMutualTLSforOAuth2orOAuth2
DemonstrationofProofofPossession(DPoP).
V10.4OAuthAuthorizationServer
These requirements detail the responsibilities for OAuth authorization servers, including OpenID
Providers.
Forclientauthentication, the‘self_signed_tls_client_auth’methodisallowedwiththeprerequisites
requiredbysection2.2ofRFC8705.
# Description Level
10.4.1 VerifythattheauthorizationservervalidatesredirectURIsbasedona 1
client‑specificallowlistofpre‑registeredURIsusingexactstringcomparison.
10.4.2 Verifythat,iftheauthorizationserverreturnstheauthorizationcodeinthe 1
authorizationresponse,itcanbeusedonlyonceforatokenrequest. Forthe
secondvalidrequestwithanauthorizationcodethathasalreadybeenused
toissueanaccesstoken,theauthorizationservermustrejectatokenrequest
andrevokeanyissuedtokensrelatedtotheauthorizationcode.
10.4.3 Verifythattheauthorizationcodeisshort‑lived. Themaximumlifetimecan 1
beupto10minutesforL1andL2applicationsandupto1minuteforL3
applications.
10.4.4 Verifythatforagivenclient,theauthorizationserveronlyallowstheusage 1
ofgrantsthatthisclientneedstouse. Notethatthegrants‘token’(Implicit
flow)and‘password’(ResourceOwnerPasswordCredentialsflow)mustno
longerbeused.
65

ApplicationSecurityVerificationStandard May2025
# Description Level
10.4.5 Verifythattheauthorizationservermitigatesrefreshtokenreplayattacksfor 1
publicclients,preferablyusingsender‑constrainedrefreshtokens,i.e.,
DemonstratingProofofPossession(DPoP)orCertificate‑BoundAccess
TokensusingmutualTLS(mTLS).ForL1andL2applications,refreshtoken
rotationmaybeused. Ifrefreshtokenrotationisused,theauthorization
servermustinvalidatetherefreshtokenafterusage,andrevokeallrefresh
tokensforthatauthorizationifanalreadyusedandinvalidatedrefreshtoken
isprovided.
10.4.6 Verifythat,ifthecodegrantisused,theauthorizationservermitigates 2
authorizationcodeinterceptionattacksbyrequiringproofkeyforcode
exchange(PKCE).Forauthorizationrequests,theauthorizationservermust
requireavalid‘code_challenge’valueandmustnotaccepta
‘code_challenge_method’valueof‘plain’. Foratokenrequest,itmustrequire
validationofthe‘code_verifier’parameter.
10.4.7 Verifythatiftheauthorizationserversupportsunauthenticateddynamic 2
clientregistration,itmitigatestheriskofmaliciousclientapplications. It
mustvalidateclientmetadatasuchasanyregisteredURIs,ensuretheuser’s
consent,andwarntheuserbeforeprocessinganauthorizationrequestwith
anuntrustedclientapplication.
10.4.8 Verifythatrefreshtokenshaveanabsoluteexpiration,includingifsliding 2
refreshtokenexpirationisapplied.
10.4.9 Verifythatrefreshtokensandreferenceaccesstokenscanberevokedbyan 2
authorizeduserusingtheauthorizationserveruserinterface,tomitigatethe
riskofmaliciousclientsorstolentokens.
10.4.10 Verifythatconfidentialclientisauthenticatedforclient‑to‑authorizedserver 2
backchannelrequestssuchastokenrequests,pushedauthorizationrequests
(PAR),andtokenrevocationrequests.
10.4.11 Verifythattheauthorizationserverconfigurationonlyassignstherequired 2
scopestotheOAuthclient.
10.4.12 Verifythatforagivenclient,theauthorizationserveronlyallowsthe 3
‘response_mode’valuethatthisclientneedstouse. Forexample,byhaving
theauthorizationservervalidatethisvalueagainsttheexpectedvaluesorby
usingpushedauthorizationrequest(PAR)orJWT‑securedAuthorization
Request(JAR).
10.4.13 Verifythatgranttype‘code’isalwaysusedtogetherwithpushed 3
authorizationrequests(PAR).
66

ApplicationSecurityVerificationStandard May2025
# Description Level
10.4.14 Verifythattheauthorizationserverissuesonlysender‑constrained 3
(Proof‑of‑Possession)accesstokens,eitherwithcertificate‑boundaccess
tokensusingmutualTLS(mTLS)orDPoP‑boundaccesstokens
(DemonstrationofProofofPossession).
10.4.15 Verifythat,foraserver‑sideclient(whichisnotexecutedontheend‑user 3
device),theauthorizationserverensuresthatthe‘authorization_details’
parametervalueisfromtheclientbackendandthattheuserhasnot
tamperedwithit. Forexample,byrequiringtheusageofpushed
authorizationrequest(PAR)orJWT‑securedAuthorizationRequest(JAR).
10.4.16 Verifythattheclientisconfidentialandtheauthorizationserverrequiresthe 3
useofstrongclientauthenticationmethods(basedonpublic‑key
cryptographyandresistanttoreplayattacks),suchasmutualTLS(
‘tls_client_auth’,‘self_signed_tls_client_auth’)orprivatekeyJWT(
‘private_key_jwt’).
V10.5OIDCClient
AstheOIDCrelyingpartyactsasanOAuthclient,therequirementsfromthesection“OAuthClient”
applyaswell.
Notethatthe“AuthenticationwithanIdentityProvider”sectioninthe“Authentication”chapteralso
containsrelevantgeneralrequirements.
# Description Level
10.5.1 Verifythattheclient(astherelyingparty)mitigatesIDTokenreplayattacks. 2
Forexample,byensuringthatthe‘nonce’claimintheIDTokenmatchesthe
‘nonce’valuesentintheauthenticationrequesttotheOpenIDProvider(in
OAuth2refereedtoastheauthorizationrequestsenttotheauthorization
server).
10.5.2 VerifythattheclientuniquelyidentifiestheuserfromIDTokenclaims, 2
usuallythe‘sub’claim,whichcannotbereassignedtootherusers(forthe
scopeofanidentityprovider).
10.5.3 Verifythattheclientrejectsattemptsbyamaliciousauthorizationserverto 2
impersonateanotherauthorizationserverthroughauthorizationserver
metadata. Theclientmustrejectauthorizationservermetadataiftheissuer
URLintheauthorizationservermetadatadoesnotexactlymatchthe
pre‑configuredissuerURLexpectedbytheclient.
67

ApplicationSecurityVerificationStandard May2025
# Description Level
10.5.4 VerifythattheclientvalidatesthattheIDTokenisintendedtobeusedfor 2
thatclient(audience)bycheckingthatthe‘aud’claimfromthetokenisequal
tothe‘client_id’valuefortheclient.
10.5.5 Verifythat,whenusingOIDCback‑channellogout,therelyingparty 2
mitigatesdenialofservicethroughforcedlogoutandcross‑JWTconfusionin
thelogoutflow. Theclientmustverifythatthelogouttokeniscorrectlytyped
withavalueof‘logout+jwt’,containsthe‘event’claimwiththecorrect
membername,anddoesnotcontaina‘nonce’claim. Notethatitisalso
recommendedtohaveashortexpiration(e.g.,2minutes).
V10.6OpenIDProvider
AsOpenIDProvidersactasOAuthauthorizationservers,therequirementsfromthesection“OAuth
AuthorizationServer”applyaswell.
NotethatifusingtheIDTokenflow(notthecodeflow),noaccesstokensareissued,andmanyofthe
requirementsforOAuthASarenotapplicable.
# Description Level
10.6.1 VerifythattheOpenIDProvideronlyallowsvalues‘code’,‘ciba’,‘id_token’, 2
or‘id_tokencode’forresponsemode. Notethat‘code’ispreferredover
‘id_tokencode’(theOIDCHybridflow),and‘token’(anyImplicitflow)must
notbeused.
10.6.2 VerifythattheOpenIDProvidermitigatesdenialofservicethroughforced 2
logout. Byobtainingexplicitconfirmationfromtheend‑useror,ifpresent,
validatingparametersinthelogoutrequest(initiatedbytherelyingparty),
suchasthe‘id_token_hint’.
V10.7ConsentManagement
These requirements cover the verification of the user’s consent by the authorization server. With‑
outproperuserconsentverification,amaliciousactormayobtainpermissionsontheuser’sbehalf
throughspoofingorsocial‑engineering.
68

ApplicationSecurityVerificationStandard May2025
# Description Level
10.7.1 Verifythattheauthorizationserverensuresthattheuserconsentstoeach 2
authorizationrequest. Iftheidentityoftheclientcannotbeassured,the
authorizationservermustalwaysexplicitlyprompttheuserforconsent.
10.7.2 Verifythatwhentheauthorizationserverpromptsforuserconsent,it 2
presentssufficientandclearinformationaboutwhatisbeingconsentedto.
Whenapplicable,thisshouldincludethenatureoftherequested
authorizations(typicallybasedonscope,resourceserver,RichAuthorization
Requests(RAR)authorizationdetails),theidentityoftheauthorized
application,andthelifetimeoftheseauthorizations.
10.7.3 Verifythattheusercanreview,modify,andrevokeconsentswhichtheuser 2
hasgrantedthroughtheauthorizationserver.
References
FormoreinformationonOAuth,pleasesee:
• oauth.net
• OWASPOAuth2.0ProtocolCheatSheet
ForOAuth‑relatedrequirementsinASVSfollowingpublishedandindraftstatusRFC‑sareused:
• RFC6749TheOAuth2.0AuthorizationFramework
• RFC6750TheOAuth2.0AuthorizationFramework: BearerTokenUsage
• RFC6819OAuth2.0ThreatModelandSecurityConsiderations
• RFC7636ProofKeyforCodeExchangebyOAuthPublicClients
• RFC7591OAuth2.0DynamicClientRegistrationProtocol
• RFC8628OAuth2.0DeviceAuthorizationGrant
• RFC8707ResourceIndicatorsforOAuth2.0
• RFC9068JSONWebToken(JWT)ProfileforOAuth2.0AccessTokens
• RFC9126OAuth2.0PushedAuthorizationRequests
• RFC9207OAuth2.0AuthorizationServerIssuerIdentification
• RFC9396OAuth2.0RichAuthorizationRequests
• RFC9449OAuth2.0DemonstratingProofofPossession(DPoP)
• RFC9700BestCurrentPracticeforOAuth2.0Security
• draftOAuth2.0forBrowser‑BasedApplications
• draftTheOAuth2.1AuthorizationFramework
FormoreinformationonOpenIDConnect,pleasesee:
• OpenIDConnectCore1.0
69

ApplicationSecurityVerificationStandard May2025
• FAPI2.0SecurityProfile
V11Cryptography
ControlObjective
Theobjectiveofthischapteristodefinebestpracticesforthegeneraluseofcryptography,aswellas
toinstillafundamentalunderstandingofcryptographicprinciplesandinspireashifttowardmore
resilientandmodernapproaches. Itencouragesthefollowing:
• Implementing robust cryptographic systems that fail securely, adapt to evolving threats, and
arefuture‑proof.
• Utilizingcryptographicmechanismsthatarebothsecureandalignedwithindustrybestprac‑
tices.
• Maintainingasecurecryptographickeymanagementsystemwithappropriateaccesscontrols
andauditing.
• Regularlyevaluatingthecryptographiclandscapetoassessnewrisksandadaptalgorithmsac‑
cordingly.
• Discovering and managing cryptographic use cases throughout the application’s lifecycle to
ensurethatallcryptographicassetsareaccountedforandsecured.
Inadditiontooutlininggeneralprinciplesandbestpractices,thisdocumentalsoprovidesmorein‑
depthtechnicalinformationabouttherequirementsinAppendixC‑CryptographyStandards. This
includesalgorithmsandmodesthatareconsidered“approved”forthepurposesoftherequirements
inthischapter.
Requirements that use cryptography to solve a separate problem, such as secrets management or
communicationssecurity,willbeindifferentpartsofthestandard.
V11.1CryptographicInventoryandDocumentation
Applications need to be designed with strong cryptographic architecture to protect data assets ac‑
cordingtotheirclassification. Encryptingeverythingiswasteful;notencryptinganythingislegally
negligent. Abalancemustbestruck,usuallyduringarchitecturalorhigh‑leveldesign,designsprints,
orarchitecturalspikes. Designingcryptography“onthefly”orretrofittingitwillinevitablycostmuch
moretoimplementsecurelythansimplybuildingitinfromthestart.
Itisimportanttoensurethatallcryptographicassetsareregularlydiscovered,inventoried,andas‑
sessed. Pleaseseetheappendixformoreinformationonhowthiscanbedone.
The need to future‑proof cryptographic systems against the eventual rise of quantum computing
is also critical. Post‑Quantum Cryptography (PQC) refers to cryptographic algorithms designed to
70

ApplicationSecurityVerificationStandard May2025
remainsecureagainstattacksbyquantumcomputers, whichareexpectedtobreakwidelyusedal‑
gorithmssuchasRSAandellipticcurvecryptography(ECC).
PleaseseetheappendixforcurrentguidanceonvettedPQCprimitivesandstandards.
# Description Level
11.1.1 Verifythatthereisadocumentedpolicyformanagementofcryptographic 2
keysandacryptographickeylifecyclethatfollowsakeymanagement
standardsuchasNISTSP800‑57. Thisshouldincludeensuringthatkeysare
notovershared(forexample,withmorethantwoentitiesforsharedsecrets
andmorethanoneentityforprivatekeys).
11.1.2 Verifythatacryptographicinventoryisperformed,maintained,regularly 2
updated,andincludesallcryptographickeys,algorithms,andcertificates
usedbytheapplication. Itmustalsodocumentwherekeyscanandcannot
beusedinthesystem,andthetypesofdatathatcanandcannotbeprotected
usingthekeys.
11.1.3 Verifythatcryptographicdiscoverymechanismsareemployedtoidentifyall 3
instancesofcryptographyinthesystem,includingencryption,hashing,and
signingoperations.
11.1.4 Verifythatacryptographicinventoryismaintained. Thismustincludea 3
documentedplanthatoutlinesthemigrationpathtonewcryptographic
standards,suchaspost‑quantumcryptography,inordertoreacttofuture
threats.
V11.2SecureCryptographyImplementation
Thissectiondefinestherequirementsfortheselection,implementation,andongoingmanagement
of core cryptographic algorithms for an application. The objective is to ensure that only robust,
industry‑acceptedcryptographicprimitivesaredeployed,inalignmentwithcurrentstandards(e.g.,
NIST, ISO/IEC) and best practices. Organizations must ensure that each cryptographic component
isselectedbasedonpeer‑reviewedevidenceandpracticalsecuritytesting.
# Description Level
11.2.1 Verifythatindustry‑validatedimplementations(includinglibrariesand 2
hardware‑acceleratedimplementations)areusedforcryptographic
operations.
71

ApplicationSecurityVerificationStandard May2025
# Description Level
11.2.2 Verifythattheapplicationisdesignedwithcryptoagilitysuchthatrandom 2
number,authenticatedencryption,MAC,orhashingalgorithms,key
lengths,rounds,ciphersandmodescanbereconfigured,upgraded,or
swappedatanytime,toprotectagainstcryptographicbreaks. Similarly,it
mustalsobepossibletoreplacekeysandpasswordsandre‑encryptdata.
Thiswillallowforseamlessupgradestopost‑quantumcryptography(PQC),
oncehigh‑assuranceimplementationsofapprovedPQCschemesor
standardsarewidelyavailable.
11.2.3 Verifythatallcryptographicprimitivesutilizeaminimumof128‑bitsof 2
securitybasedonthealgorithm,keysize,andconfiguration. Forexample,a
256‑bitECCkeyprovidesroughly128bitsofsecuritywhereRSArequiresa
3072‑bitkeytoachieve128bitsofsecurity.
11.2.4 Verifythatallcryptographicoperationsareconstant‑time,withno 3
‘short‑circuit’operationsincomparisons,calculations,orreturns,toavoid
leakinginformation.
11.2.5 Verifythatallcryptographicmodulesfailsecurely,anderrorsarehandledin 3
awaythatdoesnotenablevulnerabilities,suchasPaddingOracleattacks.
V11.3EncryptionAlgorithms
Authenticated encryption algorithms built on AES and CHACHA20 form the backbone of modern
cryptographicpractice.
# Description Level
11.3.1 Verifythatinsecureblockmodes(e.g.,ECB)andweakpaddingschemes 1
(e.g.,PKCS#1v1.5)arenotused.
11.3.2 VerifythatonlyapprovedciphersandmodessuchasAESwithGCMareused. 1
11.3.3 Verifythatencrypteddataisprotectedagainstunauthorizedmodification 2
preferablybyusinganapprovedauthenticatedencryptionmethodorby
combininganapprovedencryptionmethodwithanapprovedMAC
algorithm.
11.3.4 Verifythatnonces,initializationvectors,andothersingle‑usenumbersare 3
notusedformorethanoneencryptionkeyanddata‑elementpair. The
methodofgenerationmustbeappropriateforthealgorithmbeingused.
72

ApplicationSecurityVerificationStandard May2025
# Description Level
11.3.5 VerifythatanycombinationofanencryptionalgorithmandaMAC 3
algorithmisoperatinginencrypt‑then‑MACmode.
V11.4HashingandHash‑basedFunctions
Cryptographichashesareusedinawidevarietyofcryptographicprotocols,suchasdigitalsignatures,
HMAC,keyderivationfunctions(KDF),randombitgeneration,andpasswordstorage. Thesecurity
of the cryptographic system is only as strong as the underlying hash functions used. This section
outlinestherequirementsforusingsecurehashfunctionsincryptographicoperations.
For password storage, as well as the cryptography appendix, the OWASP Password Storage Cheat
Sheetwillalsoprovideusefulcontextandguidance.
# Description Level
11.4.1 Verifythatonlyapprovedhashfunctionsareusedforgeneralcryptographic 1
usecases,includingdigitalsignatures,HMAC,KDF,andrandombit
generation. Disallowedhashfunctions,suchasMD5,mustnotbeusedfor
anycryptographicpurpose.
11.4.2 Verifythatpasswordsarestoredusinganapproved,computationally 2
intensive,keyderivationfunction(alsoknownasa“passwordhashing
function”),withparametersettingsconfiguredbasedoncurrentguidance.
Thesettingsshouldbalancesecurityandperformancetomakebrute‑force
attackssufficientlychallengingfortherequiredlevelofsecurity.
11.4.3 Verifythathashfunctionsusedindigitalsignatures,aspartofdata 2
authenticationordataintegrityarecollisionresistantandhaveappropriate
bit‑lengths. Ifcollisionresistanceisrequired,theoutputlengthmustbeat
least256bits. Ifonlyresistancetosecondpre‑imageattacksisrequired,the
outputlengthmustbeatleast128bits.
11.4.4 Verifythattheapplicationusesapprovedkeyderivationfunctionswithkey 2
stretchingparameterswhenderivingsecretkeysfrompasswords. The
parametersinusemustbalancesecurityandperformancetoprevent
brute‑forceattacksfromcompromisingtheresultingcryptographickey.
V11.5RandomValues
CryptographicallysecurePseudo‑randomNumberGeneration(CSPRNG)isincrediblydifficulttoget
right. Generally,goodsourcesofentropywithinasystemwillbequicklydepletedifover‑used,but
73

ApplicationSecurityVerificationStandard May2025
sourceswithlessrandomnesscanleadtopredictablekeysandsecrets.
# Description Level
11.5.1 Verifythatallrandomnumbersandstringswhichareintendedtobe 2
non‑guessablemustbegeneratedusingacryptographicallysecure
pseudo‑randomnumbergenerator(CSPRNG)andhaveatleast128bitsof
entropy. NotethatUUIDsdonotrespectthiscondition.
11.5.2 Verifythattherandomnumbergenerationmechanisminuseisdesignedto 3
worksecurely,evenunderheavydemand.
V11.6PublicKeyCryptography
PublicKeyCryptographywillbeusedwhereitisnotpossibleornotdesirabletoshareasecretkey
betweenmultipleparties.
Aspartofthis,thereexistsaneedforapprovedkeyexchangemechanisms,suchasDiffie‑Hellman
and Elliptic Curve Diffie‑Hellman (ECDH) to ensure that the cryptosystem remains secure against
modernthreats. The“SecureCommunication”chapterprovidesrequirementsforTLSsotherequire‑
mentsinthissectionareintendedforsituationswherePublicKeyCryptographyisbeingusedinuse
casesotherthanTLS.
# Description Level
11.6.1 Verifythatonlyapprovedcryptographicalgorithmsandmodesofoperation 2
areusedforkeygenerationandseeding,anddigitalsignaturegeneration
andverification. Keygenerationalgorithmsmustnotgenerateinsecurekeys
vulnerabletoknownattacks,forexample,RSAkeyswhicharevulnerableto
Fermatfactorization.
11.6.2 Verifythatapprovedcryptographicalgorithmsareusedforkeyexchange 3
(suchasDiffie‑Hellman)withafocusonensuringthatkeyexchange
mechanismsusesecureparameters. Thiswillpreventattacksonthekey
establishmentprocesswhichcouldleadtoadversary‑in‑the‑middleattacks
orcryptographicbreaks.
V11.7In‑UseDataCryptography
Protectingdatawhileitisbeingprocessedisparamount. Techniquessuchasfullmemoryencryp‑
tion,encryptionofdataintransit,andensuringdataisencryptedasquicklyaspossibleafteruseis
recommended.
74

ApplicationSecurityVerificationStandard May2025
# Description Level
11.7.1 Verifythatfullmemoryencryptionisinusethatprotectssensitivedata 3
whileitisinuse,preventingaccessbyunauthorizedusersorprocesses.
11.7.2 Verifythatdataminimizationensurestheminimalamountofdatais 3
exposedduringprocessing,andensurethatdataisencryptedimmediately
afteruseorassoonasfeasible.
References
Formoreinformation,seealso:
• OWASPWebSecurityTestingGuide: TestingforWeakCryptography
• OWASPCryptographicStorageCheatSheet
• FIPS140‑3
• NISTSP800‑57
V12SecureCommunication
ControlObjective
This chapter includes requirements related to the specific mechanisms that should be in place to
protect data in transit, both between an end‑user client and a backend service, as well as between
internalandbackendservices.
Thegeneralconceptspromotedbythischapterinclude:
• Ensuringthatcommunicationsareencryptedexternally,andideallyinternallyaswell.
• Configuringencryptionmechanismsusingthelatestguidance,includingpreferredalgorithms
andciphers.
• Usingsignedcertificatestoensurethatcommunicationsarenotbeinginterceptedbyunautho‑
rizedparties.
Inadditiontooutlininggeneralprinciplesandbestpractices,theASVSalsoprovidesmorein‑depth
technicalinformationaboutcryptographicstrengthinAppendixC‑CryptographyStandards.
V12.1GeneralTLSSecurityGuidance
ThissectionprovidesinitialguidanceonhowtosecureTLScommunications. Up‑to‑datetoolsshould
beusedtoreviewTLSconfigurationonanongoingbasis.
75

ApplicationSecurityVerificationStandard May2025
WhiletheuseofwildcardTLScertificatesisnotinherentlyinsecure, acompromiseofacertificate
that is deployed across all owned environments (e.g., production, staging, development, and test)
may lead to a compromise of the security posture of the applications using it. Proper protection,
management,andtheuseofseparateTLScertificatesindifferentenvironmentsshouldbeemployed
ifpossible.
# Description Level
12.1.1 VerifythatonlythelatestrecommendedversionsoftheTLSprotocolare 1
enabled,suchasTLS1.2andTLS1.3. ThelatestversionoftheTLSprotocol
mustbethepreferredoption.
12.1.2 Verifythatonlyrecommendedciphersuitesareenabled,withthestrongest 2
ciphersuitessetaspreferred. L3applicationsmustonlysupportcipher
suiteswhichprovideforwardsecrecy.
12.1.3 VerifythattheapplicationvalidatesthatmTLSclientcertificatesaretrusted 2
beforeusingthecertificateidentityforauthenticationorauthorization.
12.1.4 Verifythatpropercertificationrevocation,suchasOnlineCertificateStatus 3
Protocol(OCSP)Stapling,isenabledandconfigured.
12.1.5 VerifythatEncryptedClientHello(ECH)isenabledintheapplication’sTLS 3
settingstopreventexposureofsensitivemetadata,suchastheServerName
Indication(SNI),duringTLShandshakeprocesses.
V12.2HTTPSCommunicationwithExternalFacingServices
EnsureallHTTPtraffictoexternal‑facingserviceswhichtheapplicationexposesissentencrypted,
withpubliclytrustedcertificates.
# Description Level
12.2.1 VerifythatTLSisusedforallconnectivitybetweenaclientandexternal 1
facing,HTTP‑basedservices,anddoesnotfallbacktoinsecureor
unencryptedcommunications.
12.2.2 VerifythatexternalfacingservicesusepubliclytrustedTLScertificates. 1
V12.3GeneralServicetoServiceCommunicationSecurity
Server communications (both internal and external) involve more than just HTTP. Connections to
andfromothersystemsmustalsobesecure,ideallyusingTLS.
76

ApplicationSecurityVerificationStandard May2025
# Description Level
12.3.1 VerifythatanencryptedprotocolsuchasTLSisusedforallinboundand 2
outboundconnectionstoandfromtheapplication,includingmonitoring
systems,managementtools,remoteaccessandSSH,middleware,databases,
mainframes,partnersystems,orexternalAPIs. Theservermustnotfall
backtoinsecureorunencryptedprotocols.
12.3.2 VerifythatTLSclientsvalidatecertificatesreceivedbeforecommunicating 2
withaTLSserver.
12.3.3 VerifythatTLSoranotherappropriatetransportencryptionmechanism 2
usedforallconnectivitybetweeninternal,HTTP‑basedserviceswithinthe
application,anddoesnotfallbacktoinsecureorunencrypted
communications.
12.3.4 VerifythatTLSconnectionsbetweeninternalservicesusetrusted 2
certificates. Whereinternallygeneratedorself‑signedcertificatesareused,
theconsumingservicemustbeconfiguredtoonlytrustspecificinternalCAs
andspecificself‑signedcertificates.
12.3.5 Verifythatservicescommunicatinginternallywithinasystem(intra‑service 3
communications)usestrongauthenticationtoensurethateachendpointis
verified. Strongauthenticationmethods,suchasTLSclientauthentication,
mustbeemployedtoensureidentity,usingpublic‑keyinfrastructureand
mechanismsthatareresistanttoreplayattacks. Formicroservice
architectures,considerusingaservicemeshtosimplifycertificate
managementandenhancesecurity.
References
Formoreinformation,seealso:
• OWASP‑TransportLayerSecurityCheatSheet
• Mozilla’sServerSideTLSconfigurationguide
• Mozilla’stooltogenerateknowngoodTLSconfigurations.
• O‑Saft‑OWASPProjecttovalidateTLSconfiguration
V13Configuration
ControlObjective
Theapplication’sdefaultconfigurationmustbesecureforuseontheInternet.
77

ApplicationSecurityVerificationStandard May2025
This chapter provides guidance on the various configurations necessary to achieve this, including
thoseappliedduringdevelopment,build,anddeployment.
Topicscoveredincludepreventingdataleakage, securelymanagingcommunicationbetweencom‑
ponents,andprotectingsecrets.
V13.1ConfigurationDocumentation
This section outlines documentation requirements for how the application communicates with in‑
ternalandexternalservices,aswellastechniquestopreventlossofavailabilityduetoserviceinac‑
cessibility. Italsoaddressesdocumentationrelatedtosecrets.
# Description Level
13.1.1 Verifythatallcommunicationneedsfortheapplicationaredocumented. 2
Thismustincludeexternalserviceswhichtheapplicationreliesuponand
caseswhereanendusermightbeabletoprovideanexternallocationto
whichtheapplicationwillthenconnect.
13.1.2 Verifythatforeachservicetheapplicationuses,thedocumentationdefines 3
themaximumnumberofconcurrentconnections(e.g.,connectionpool
limits)andhowtheapplicationbehaveswhenthatlimitisreached,
includinganyfallbackorrecoverymechanisms,topreventdenialofservice
conditions.
13.1.3 Verifythattheapplicationdocumentationdefinesresource‑management 3
strategiesforeveryexternalsystemorserviceituses(e.g.,databases,file
handles,threads,HTTPconnections). Thisshouldincluderesource‑release
procedures,timeoutsettings,failurehandling,andwhereretrylogicis
implemented,specifyingretrylimits,delays,andback‑offalgorithms. For
synchronousHTTPrequest–responseoperationsitshouldmandateshort
timeoutsandeitherdisableretriesorstrictlylimitretriestoprevent
cascadingdelaysandresourceexhaustion.
13.1.4 Verifythattheapplication’sdocumentationdefinesthesecretsthatare 3
criticalforthesecurityoftheapplicationandascheduleforrotatingthem,
basedontheorganization’sthreatmodelandbusinessrequirements.
V13.2BackendCommunicationConfiguration
Applicationsinteractwithmultipleservices,includingAPIs,databases,orothercomponents. These
maybeconsideredinternaltotheapplicationbutnotincludedintheapplication’sstandardaccess
controlmechanisms,ortheymaybeentirelyexternal. Ineithercase,itisnecessarytoconfigurethe
applicationtointeractsecurelywiththesecomponentsand,ifrequired,protectthatconfiguration.
78

ApplicationSecurityVerificationStandard May2025
Note: The“SecureCommunication”chapterprovidesguidanceforencryptionintransit.
# Description Level
13.2.1 Verifythatcommunicationsbetweenbackendapplicationcomponentsthat 2
don’tsupporttheapplication’sstandardusersessionmechanism,including
APIs,middleware,anddatalayers,areauthenticated. Authenticationmust
useindividualserviceaccounts,short‑termtokens,orcertificate‑based
authenticationandnotunchangingcredentialssuchaspasswords,APIkeys,
orsharedaccountswithprivilegedaccess.
13.2.2 Verifythatcommunicationsbetweenbackendapplicationcomponents, 2
includinglocaloroperatingsystemservices,APIs,middleware,anddata
layers,areperformedwithaccountsassignedtheleastnecessaryprivileges.
13.2.3 Verifythatifacredentialhastobeusedforserviceauthentication,the 2
credentialbeingusedbytheconsumerisnotadefaultcredential(e.g.,
root/rootoradmin/admin).
13.2.4 Verifythatanallowlistisusedtodefinetheexternalresourcesorsystems 2
withwhichtheapplicationispermittedtocommunicate(e.g.,foroutbound
requests,dataloads,orfileaccess). Thisallowlistcanbeimplementedatthe
applicationlayer,webserver,firewall,oracombinationofdifferentlayers.
13.2.5 Verifythattheweborapplicationserverisconfiguredwithanallowlistof 2
resourcesorsystemstowhichtheservercansendrequestsorloaddataor
filesfrom.
13.2.6 Verifythatwheretheapplicationconnectstoseparateservices,itfollowsthe 3
documentedconfigurationforeachconnection,suchasmaximumparallel
connections,behaviorwhenmaximumallowedconnectionsisreached,
connectiontimeouts,andretrystrategies.
V13.3SecretManagement
Secret management is an essential configuration task to ensure the protection of data used in the
application. Specificrequirementsforcryptographycanbefoundinthe“Cryptography”chapter,but
thissectionfocusesonthemanagementandhandlingaspectsofsecrets.
79

ApplicationSecurityVerificationStandard May2025
# Description Level
13.3.1 Verifythatasecretsmanagementsolution,suchasakeyvault,isusedto 2
securelycreate,store,controlaccessto,anddestroybackendsecrets. These
couldincludepasswords,keymaterial,integrationswithdatabasesand
third‑partysystems,keysandseedsfortime‑basedtokens,otherinternal
secrets,andAPIkeys. Secretsmustnotbeincludedinapplicationsource
codeorincludedinbuildartifacts. ForanL3application,thismustinvolvea
hardware‑backedsolutionsuchasanHSM.
13.3.2 Verifythataccesstosecretassetsadherestotheprincipleofleastprivilege. 2
13.3.3 Verifythatallcryptographicoperationsareperformedusinganisolated 3
securitymodule(suchasavaultorhardwaresecuritymodule)tosecurely
manageandprotectkeymaterialfromexposureoutsideofthesecurity
module.
13.3.4 Verifythatsecretsareconfiguredtoexpireandberotatedbasedonthe 3
application’sdocumentation.
V13.4UnintendedInformationLeakage
Productionconfigurationsshouldbehardenedtoavoiddisclosingunnecessarydata. Manyofthese
issues are rarely rated as significant risks but are often chained with other vulnerabilities. If these
issuesarenotpresentbydefault,itraisesthebarforattackinganapplication.
Forexample,hidingtheversionofserver‑sidecomponentsdoesnoteliminatetheneedtopatchall
components,anddisablingfolderlistingdoesnotremovetheneedtouseauthorizationcontrolsor
keepfilesawayfromthepublicfolder,butitraisesthebar.
# Description Level
13.4.1 Verifythattheapplicationisdeployedeitherwithoutanysourcecontrol 1
metadata,includingthe.gitor.svnfolders,orinawaythatthesefoldersare
inaccessiblebothexternallyandtotheapplicationitself.
13.4.2 Verifythatdebugmodesaredisabledforallcomponentsinproduction 2
environmentstopreventexposureofdebuggingfeaturesandinformation
leakage.
13.4.3 Verifythatwebserversdonotexposedirectorylistingstoclientsunless 2
explicitlyintended.
13.4.4 VerifythatusingtheHTTPTRACEmethodisnotsupportedinproduction 2
environments,toavoidpotentialinformationleakage.
80

ApplicationSecurityVerificationStandard May2025
# Description Level
13.4.5 Verifythatdocumentation(suchasforinternalAPIs)andmonitoring 2
endpointsarenotexposedunlessexplicitlyintended.
13.4.6 Verifythattheapplicationdoesnotexposedetailedversioninformationof 3
backendcomponents.
13.4.7 Verifythatthewebtierisconfiguredtoonlyservefileswithspecificfile 3
extensionstopreventunintentionalinformation,configuration,andsource
codeleakage.
References
Formoreinformation,seealso:
• OWASPWebSecurityTestingGuide: ConfigurationandDeploymentManagementTesting
V14DataProtection
ControlObjective
Applicationscannotaccountforallusagepatternsanduserbehaviors,andshouldthereforeimple‑
mentcontrolstolimitunauthorizedaccesstosensitivedataonclientdevices.
Thischapterincludesrequirementsrelatedtodefiningwhatdataneedstobeprotected,howitshould
beprotected,andspecificmechanismstoimplementorpitfallstoavoid.
Anotherconsiderationfordataprotectionisbulkextraction,modification,orexcessiveusage. Each
system’srequirementsarelikelytobeverydifferent, sodeterminingwhatis“abnormal”mustcon‑
siderthethreatmodelandbusinessrisk. FromanASVSperspective,detectingtheseissuesishandled
inthe“SecurityLoggingandErrorHandling”chapter,andsettinglimitsishandledinthe“Validation
andBusinessLogic”chapter.
V14.1DataProtectionDocumentation
A key prerequisite for being able to protect data is to categorize what data should be considered
sensitive. Therearelikelytobeseveraldifferentlevelsofsensitivity,andforeachlevel,thecontrols
requiredtoprotectdataatthatlevelwillbedifferent.
Therearevariousprivacyregulationsandlawsthataffecthowapplicationsmustapproachthestor‑
age,use,andtransmissionofsensitivepersonalinformation. Thissectionnolongertriestoduplicate
81

ApplicationSecurityVerificationStandard May2025
thesetypesofdataprotectionorprivacylegislation,butratherfocusesonkeytechnicalconsidera‑
tionsforprotectingsensitivedata. Pleaseconsultlocallawsandregulations,andconsultaqualified
privacyspecialistorlawyerasrequired.
# Description Level
14.1.1 Verifythatallsensitivedatacreatedandprocessedbytheapplicationhas 2
beenidentifiedandclassifiedintoprotectionlevels. Thisincludesdatathatis
onlyencodedandthereforeeasilydecoded,suchasBase64stringsorthe
plaintextpayloadinsideaJWT.Protectionlevelsneedtotakeintoaccount
anydataprotectionandprivacyregulationsandstandardswhichthe
applicationisrequiredtocomplywith.
14.1.2 Verifythatallsensitivedataprotectionlevelshaveadocumentedsetof 2
protectionrequirements. Thismustinclude(butnotbelimitedto)
requirementsrelatedtogeneralencryption,integrityverification,retention,
howthedataistobelogged,accesscontrolsaroundsensitivedatainlogs,
database‑levelencryption,privacyandprivacy‑enhancingtechnologiestobe
used,andotherconfidentialityrequirements.
V14.2GeneralDataProtection
Thissectioncontainsvariouspracticalrequirementsrelatedtotheprotectionofdata. Mostarespe‑
cifictoparticularissuessuchasunintendeddataleakage,butthereisalsoageneralrequirementto
implementprotectioncontrolsbasedontheprotectionlevelrequiredforeachdataitem.
# Description Level
14.2.1 VerifythatsensitivedataisonlysenttotheserverintheHTTPmessagebody 1
orheaderfields,andthattheURLandquerystringdonotcontainsensitive
information,suchasanAPIkeyorsessiontoken.
14.2.2 Verifythattheapplicationpreventssensitivedatafrombeingcachedin 2
servercomponents,suchasloadbalancersandapplicationcaches,or
ensuresthatthedataissecurelypurgedafteruse.
14.2.3 Verifythatdefinedsensitivedataisnotsenttountrustedparties(e.g.,user 2
trackers)topreventunwantedcollectionofdataoutsideoftheapplication’s
control.
82

ApplicationSecurityVerificationStandard May2025
# Description Level
14.2.4 Verifythatcontrolsaroundsensitivedatarelatedtoencryption,integrity 2
verification,retention,howthedataistobelogged,accesscontrolsaround
sensitivedatainlogs,privacyandprivacy‑enhancingtechnologies,are
implementedasdefinedinthedocumentationforthespecificdata’s
protectionlevel.
14.2.5 Verifythatcachingmechanismsareconfiguredtoonlycacheresponses 3
whichhavetheexpectedcontenttypeforthatresourceanddonotcontain
sensitive,dynamiccontent. Thewebservershouldreturna404or302
responsewhenanon‑existentfileisaccessedratherthanreturninga
different,validfile. ThisshouldpreventWebCacheDeceptionattacks.
14.2.6 Verifythattheapplicationonlyreturnstheminimumrequiredsensitivedata 3
fortheapplication’sfunctionality. Forexample,onlyreturningsomeofthe
digitsofacreditcardnumberandnotthefullnumber. Ifthecompletedata
isrequired,itshouldbemaskedintheuserinterfaceunlesstheuser
specificallyviewsit.
14.2.7 Verifythatsensitiveinformationissubjecttodataretentionclassification, 3
ensuringthatoutdatedorunnecessarydataisdeletedautomatically,ona
definedschedule,orasthesituationrequires.
14.2.8 Verifythatsensitiveinformationisremovedfromthemetadataof 3
user‑submittedfilesunlessstorageisconsentedtobytheuser.
V14.3Client‑sideDataProtection
Thissectioncontainsrequirementspreventingdatafromleakinginspecificwaysattheclientoruser
agentsideofanapplication.
# Description Level
14.3.1 Verifythatauthenticateddataisclearedfromclientstorage,suchasthe 1
browserDOM,aftertheclientorsessionisterminated. The‘Clear‑Site‑Data’
HTTPresponseheaderfieldmaybeabletohelpwiththisbuttheclient‑side
shouldalsobeabletoclearupiftheserverconnectionisnotavailablewhen
thesessionisterminated.
14.3.2 Verifythattheapplicationsetssufficientanti‑cachingHTTPresponseheader 2
fields(i.e.,Cache‑Control: no‑store)sothatsensitivedataisnotcachedin
browsers.
83

ApplicationSecurityVerificationStandard May2025
# Description Level
14.3.3 Verifythatdatastoredinbrowserstorage(suchaslocalStorage, 2
sessionStorage,IndexedDB,orcookies)doesnotcontainsensitivedata,with
theexceptionofsessiontokens.
References
Formoreinformation,seealso:
• ConsiderusingtheSecurityHeaderswebsitetochecksecurityandanti‑cachingheaderfields
• Documentationaboutanti‑cachingheadersbyMozilla
• OWASPSecureHeadersproject
• OWASPPrivacyRisksProject
• OWASPUserPrivacyProtectionCheatSheet
• AustralianPrivacyPrinciple11‑Securityofpersonalinformation
• EuropeanUnionGeneralDataProtectionRegulation(GDPR)overview
• EuropeanUnionDataProtectionSupervisor‑InternetPrivacyEngineeringNetwork
• Informationonthe“Clear‑Site‑Data”header
• WhitepaperonWebCacheDeception
V15SecureCodingandArchitecture
ControlObjective
ManyASVSrequirementseitherrelatetoaparticularareaofsecurity,suchasauthenticationorau‑
thorization, or pertain to a particular type of application functionality, such as logging or file han‑
dling.
Thischapterprovidesgeneralsecurityrequirementstoconsiderwhendesigninganddevelopingap‑
plications. These requirements focus not only on clean architecture and code quality but also on
specificarchitectureandcodingpracticesnecessaryforapplicationsecurity.
V15.1SecureCodingandArchitectureDocumentation
Manyrequirementsforestablishingasecureanddefensiblearchitecturedependoncleardocumen‑
tationofdecisionsmaderegardingtheimplementationofspecificsecuritycontrolsandthecompo‑
nentsusedwithintheapplication.
This section outlines the documentation requirements, including identifying components consid‑
eredtocontain“dangerousfunctionality”ortobe“riskycomponents.”
84

ApplicationSecurityVerificationStandard May2025
Acomponentwith“dangerousfunctionality”maybeaninternallydevelopedorthird‑partycompo‑
nentthatperformsoperationssuchasdeserializationofuntrusteddata,rawfileorbinarydatapars‑
ing,dynamiccodeexecution,ordirectmemorymanipulation. Vulnerabilitiesinthesetypesofop‑
erations pose a high risk of compromising the application and potentially exposing its underlying
infrastructure.
A“riskycomponent”isa3rdpartylibrary(i.e.,notinternallydeveloped)withmissingorpoorlyim‑
plemented security controls around its development processes or functionality. Examples include
components that are poorly maintained, unsupported, at the end‑of‑life stage, or have a history of
significantvulnerabilities.
Thissectionalsoemphasizestheimportanceofdefiningappropriatetimeframesforaddressingvul‑
nerabilitiesinthird‑partycomponents.
# Description Level
15.1.1 Verifythatapplicationdocumentationdefinesriskbasedremediationtime 1
framesfor3rdpartycomponentversionswithvulnerabilitiesandfor
updatinglibrariesingeneral,tominimizetheriskfromthesecomponents.
15.1.2 Verifythataninventorycatalog,suchassoftwarebillofmaterials(SBOM),is 2
maintainedofallthird‑partylibrariesinuse,includingverifyingthat
componentscomefrompre‑defined,trusted,andcontinuallymaintained
repositories.
15.1.3 Verifythattheapplicationdocumentationidentifiesfunctionalitywhichis 2
time‑consumingorresource‑demanding. Thismustincludehowtoprevent
alossofavailabilityduetooverusingthisfunctionalityandhowtoavoida
situationwherebuildingaresponsetakeslongerthantheconsumer’s
timeout. Potentialdefensesmayincludeasynchronousprocessing,using
queues,andlimitingparallelprocessesperuserandperapplication.
15.1.4 Verifythatapplicationdocumentationhighlightsthird‑partylibrarieswhich 3
areconsideredtobe“riskycomponents”.
15.1.5 Verifythatapplicationdocumentationhighlightspartsoftheapplication 3
where“dangerousfunctionality”isbeingused.
V15.2SecurityArchitectureandDependencies
Thissectionincludesrequirementsforhandlingrisky,outdated,orinsecuredependenciesandcom‑
ponentsthroughdependencymanagement.
It also includes using architectural‑level techniques such as sandboxing, encapsulation, container‑
ization,andnetworkisolationtoreducetheimpactofusing“dangerousoperations”or“riskycompo‑
85

ApplicationSecurityVerificationStandard May2025
nents”(asdefinedintheprevioussection)andpreventlossofavailabilityduetooverusingresource‑
demandingfunctionality.
# Description Level
15.2.1 Verifythattheapplicationonlycontainscomponentswhichhavenot 1
breachedthedocumentedupdateandremediationtimeframes.
15.2.2 Verifythattheapplicationhasimplementeddefensesagainstlossof 2
availabilityduetofunctionalitywhichistime‑consumingor
resource‑demanding,basedonthedocumentedsecuritydecisionsand
strategiesforthis.
15.2.3 Verifythattheproductionenvironmentonlyincludesfunctionalitythatis 2
requiredfortheapplicationtofunction,anddoesnotexposeextraneous
functionalitysuchastestcode,samplesnippets,anddevelopment
functionality.
15.2.4 Verifythatthird‑partycomponentsandalloftheirtransitivedependencies 3
areincludedfromtheexpectedrepository,whetherinternallyownedoran
externalsource,andthatthereisnoriskofadependencyconfusionattack.
15.2.5 Verifythattheapplicationimplementsadditionalprotectionsaroundparts 3
oftheapplicationwhicharedocumentedascontaining“dangerous
functionality”orusingthird‑partylibrariesconsideredtobe“risky
components”. Thiscouldincludetechniquessuchassandboxing,
encapsulation,containerizationornetworklevelisolationtodelayanddeter
attackerswhocompromiseonepartofanapplicationfrompivoting
elsewhereintheapplication.
V15.3DefensiveCoding
This section covers vulnerability types, including type juggling, prototype pollution, and others,
whichresultfromusinginsecurecodingpatternsinaparticularlanguage. Somemaynotberelevant
to all languages, whereas others will have language‑specific fixes or may relate to how a particular
languageorframeworkhandlesafeaturesuchasHTTPparameters. Italsoconsiderstheriskofnot
cryptographicallyvalidatingapplicationupdates.
It also considers the risks associated with using objects to represent data items and accepting and
returningtheseviaexternalAPIs. Inthiscase,theapplicationmustensurethatdatafieldsthatshould
notbewritablearenotmodifiedbyuserinput(massassignment)andthattheAPIisselectiveabout
what data fields get returned. Where field access depends on a user’s permissions, this should be
consideredinthecontextofthefield‑levelaccesscontrolrequirementintheAuthorizationchapter.
86

ApplicationSecurityVerificationStandard May2025
# Description Level
15.3.1 Verifythattheapplicationonlyreturnstherequiredsubsetoffieldsfroma 1
dataobject. Forexample,itshouldnotreturnanentiredataobject,assome
individualfieldsshouldnotbeaccessibletousers.
15.3.2 VerifythatwheretheapplicationbackendmakescallstoexternalURLs,itis 2
configuredtonotfollowredirectsunlessitisintendedfunctionality.
15.3.3 Verifythattheapplicationhascountermeasurestoprotectagainstmass 2
assignmentattacksbylimitingallowedfieldspercontrollerandaction,e.g.,
itisnotpossibletoinsertorupdateafieldvaluewhenitwasnotintendedto
bepartofthataction.
15.3.4 Verifythatallproxyingandmiddlewarecomponentstransfertheuser’s 2
originalIPaddresscorrectlyusingtrusteddatafieldsthatcannotbe
manipulatedbytheenduser,andtheapplicationandwebserverusethis
correctvalueforloggingandsecuritydecisionssuchasratelimiting,taking
intoaccountthateventheoriginalIPaddressmaynotbereliabledueto
dynamicIPs,VPNs,orcorporatefirewalls.
15.3.5 Verifythattheapplicationexplicitlyensuresthatvariablesareofthecorrect 2
typeandperformsstrictequalityandcomparatoroperations. Thisistoavoid
typejugglingortypeconfusionvulnerabilitiescausedbytheapplication
codemakinganassumptionaboutavariabletype.
15.3.6 VerifythatJavaScriptcodeiswritteninawaythatpreventsprototype 2
pollution,forexample,byusingSet()orMap()insteadofobjectliterals.
15.3.7 VerifythattheapplicationhasdefensesagainstHTTPparameterpollution 2
attacks,particularlyiftheapplicationframeworkmakesnodistinctionabout
thesourceofrequestparameters(querystring,bodyparameters,cookies,or
headerfields).
V15.4SafeConcurrency
Concurrencyissuessuchasraceconditions,time‑of‑checktotime‑of‑use(TOCTOU)vulnerabilities,
deadlocks,livelocks,threadstarvation,andimpropersynchronizationcanleadtounpredictablebe‑
havior and security risks. This section includes various techniques and strategies to help mitigate
theserisks.
87

ApplicationSecurityVerificationStandard May2025
# Description Level
15.4.1 Verifythatsharedobjectsinmulti‑threadedcode(suchascaches,files,or 3
in‑memoryobjectsaccessedbymultiplethreads)areaccessedsafelyby
usingthread‑safetypesandsynchronizationmechanismslikelocksor
semaphorestoavoidraceconditionsanddatacorruption.
15.4.2 Verifythatchecksonaresource’sstate,suchasitsexistenceorpermissions, 3
andtheactionsthatdependonthemareperformedasasingleatomic
operationtopreventtime‑of‑checktotime‑of‑use(TOCTOU)raceconditions.
Forexample,checkingifafileexistsbeforeopeningit,orverifyingauser’s
accessbeforegrantingit.
15.4.3 Verifythatlocksareusedconsistentlytoavoidthreadsgettingstuck,whether 3
bywaitingoneachotherorretryingendlessly,andthatlockinglogicstays
withinthecoderesponsibleformanagingtheresourcetoensurelocks
cannotbeinadvertentlyormaliciouslymodifiedbyexternalclassesorcode.
15.4.4 Verifythatresourceallocationpoliciespreventthreadstarvationbyensuring 3
fairaccesstoresources,suchasbyleveragingthreadpools,allowing
lower‑prioritythreadstoproceedwithinareasonabletimeframe.
References
Formoreinformation,seealso:
• OWASPPrototypePollutionPreventionCheatSheet
• OWASPMassAssignmentPreventionCheatSheet
• OWASPCycloneDXBillofMaterialsSpecification
• OWASPWebSecurityTestingGuide: TestingforHTTPParameterPollution
V16SecurityLoggingandErrorHandling
ControlObjective
Security logs are distinct from error or performance logs and are used to record security‑relevant
events such as authentication decisions, access control decisions, and attempts to bypass security
controls,suchasinputvalidationorbusinesslogicvalidation. Theirpurposeistosupportdetection,
response,andinvestigationbyprovidinghigh‑signal,structureddataforanalysistoolslikeSIEMs.
Logsshouldnotincludesensitivepersonaldataunlesslegallyrequired,andanyloggeddatamustbe
protectedasahigh‑valueasset. Loggingmustnotcompromiseprivacyorsystemsecurity. Applica‑
tionsmustalsofailsecurely,avoidingunnecessarydisclosureordisruption.
88

ApplicationSecurityVerificationStandard May2025
Fordetailedimplementationguidance,refertotheOWASPCheatSheetsinthereferencessection.
V16.1SecurityLoggingDocumentation
Thissectionensuresaclearandcompleteinventoryofloggingacrosstheapplicationstack. Thisis
essentialforeffectivesecuritymonitoring,incidentresponse,andcompliance.
# Description Level
16.1.1 Verifythataninventoryexistsdocumentingtheloggingperformedateach 2
layeroftheapplication’stechnologystack,whateventsarebeinglogged,log
formats,wherethatloggingisstored,howitisused,howaccesstoitis
controlled,andforhowlonglogsarekept.
V16.2GeneralLogging
Thissectionprovidesrequirementstoensurethatsecuritylogsareconsistentlystructuredandcon‑
tain the expected metadata. The goal is to make logs machine‑readable and analyzable across dis‑
tributedsystemsandtools.
Naturally,securityeventsofteninvolvesensitivedata. Ifsuchdataisloggedwithoutconsideration,
thelogsthemselvesbecomeclassifiedandthereforesubjecttoencryptionrequirements,stricterre‑
tentionpolicies,andpotentialdisclosureduringaudits.
Therefore,itiscriticaltologonlywhatisnecessaryandtotreatlogdatawiththesamecareasother
sensitiveassets.
The requirements below establish foundational requirements for logging metadata, synchroniza‑
tion,format,andcontrol.
# Description Level
16.2.1 Verifythateachlogentryincludesnecessarymetadata(suchaswhen, 2
where,who,what)thatwouldallowforadetailedinvestigationofthe
timelinewhenaneventhappens.
16.2.2 Verifythattimesourcesforallloggingcomponentsaresynchronized,and 2
thattimestampsinsecurityeventmetadatauseUTCorincludeanexplicit
timezoneoffset. UTCisrecommendedtoensureconsistencyacross
distributedsystemsandtopreventconfusionduringdaylightsavingtime
transitions.
16.2.3 Verifythattheapplicationonlystoresorbroadcastslogstothefilesand 2
servicesthataredocumentedintheloginventory.
89

ApplicationSecurityVerificationStandard May2025
# Description Level
16.2.4 Verifythatlogscanbereadandcorrelatedbythelogprocessorthatisinuse, 2
preferablybyusingacommonloggingformat.
16.2.5 Verifythatwhenloggingsensitivedata,theapplicationenforceslogging 2
basedonthedata’sprotectionlevel. Forexample,itmaynotbeallowedto
logcertaindata,suchascredentialsorpaymentdetails. Otherdata,suchas
sessiontokens,mayonlybeloggedbybeinghashedormasked,eitherinfull
orpartially.
V16.3SecurityEvents
Thissectiondefinesrequirementsforloggingsecurity‑relevanteventswithintheapplication. Cap‑
turing these events is critical for detecting suspicious behavior, supporting investigations, and ful‑
fillingcomplianceobligations.
This section outlines the types of events that should be logged but does not attempt to provide ex‑
haustivedetail. Eachapplicationhasuniqueriskfactorsandoperationalcontext.
NotethatwhileASVSincludesloggingofsecurityeventsinscope,alertingandcorrelation(e.g.,SIEM
rulesormonitoringinfrastructure)areconsideredoutofscopeandarehandledbyoperationaland
monitoringsystems.
# Description Level
16.3.1 Verifythatallauthenticationoperationsarelogged,includingsuccessfuland 2
unsuccessfulattempts. Additionalmetadata,suchasthetypeof
authenticationorfactorsused,shouldalsobecollected.
16.3.2 Verifythatfailedauthorizationattemptsarelogged. ForL3,thismust 2
includeloggingallauthorizationdecisions,includingloggingwhensensitive
dataisaccessed(withoutloggingthesensitivedataitself).
16.3.3 Verifythattheapplicationlogsthesecurityeventsthataredefinedinthe 2
documentationandalsologsattemptstobypassthesecuritycontrols,such
asinputvalidation,businesslogic,andanti‑automation.
16.3.4 Verifythattheapplicationlogsunexpectederrorsandsecuritycontrol 2
failuressuchasbackendTLSfailures.
90

ApplicationSecurityVerificationStandard May2025
V16.4LogProtection
Logsarevaluableforensicartifactsandmustbeprotected. Iflogscanbeeasilymodifiedordeleted,
theylosetheirintegrityandbecomeunreliableforincidentinvestigationsorlegalproceedings. Logs
mayexposeinternalapplicationbehaviororsensitivemetadata,makingthemanattractivetargetfor
attackers.
Thissectiondefinesrequirementstoensurethatlogsareprotectedfromunauthorizedaccess,tam‑
pering,anddisclosure,andthattheyaresafelytransmittedandstoredinsecure,isolatedsystems.
# Description Level
16.4.1 Verifythatallloggingcomponentsappropriatelyencodedatatopreventlog 2
injection.
16.4.2 Verifythatlogsareprotectedfromunauthorizedaccessandcannotbe 2
modified.
16.4.3 Verifythatlogsaresecurelytransmittedtoalogicallyseparatesystemfor 2
analysis,detection,alerting,andescalation. Theaimistoensurethatifthe
applicationisbreached,thelogsarenotcompromised.
V16.5ErrorHandling
This section defines requirements to ensure that applications fail gracefully and securely without
disclosingsensitiveinternaldetails.
# Description Level
16.5.1 Verifythatagenericmessageisreturnedtotheconsumerwhenan 2
unexpectedorsecurity‑sensitiveerroroccurs,ensuringnoexposureof
sensitiveinternalsystemdatasuchasstacktraces,queries,secretkeys,and
tokens.
16.5.2 Verifythattheapplicationcontinuestooperatesecurelywhenexternal 2
resourceaccessfails,forexample,byusingpatternssuchascircuitbreakers
orgracefuldegradation.
16.5.3 Verifythattheapplicationfailsgracefullyandsecurely,includingwhenan 2
exceptionoccurs,preventingfail‑openconditionssuchasprocessinga
transactiondespiteerrorsresultingfromvalidationlogic.
91

ApplicationSecurityVerificationStandard May2025
# Description Level
16.5.4 Verifythata“lastresort”errorhandlerisdefinedwhichwillcatchall 3
unhandledexceptions. Thisisbothtoavoidlosingerrordetailsthatmustgo
tologfilesandtoensurethatanerrordoesnottakedowntheentire
applicationprocess,leadingtoalossofavailability.
Note: Certain languages, (including Swift, Go, and through common design practice, many func‑
tional languages,) do not support exceptions or last‑resort event handlers. In this case, architects
and developers should use a pattern, language, or framework‑friendly way to ensure that applica‑
tionscansecurelyhandleexceptional,unexpected,orsecurity‑relatedevents.
References
Formoreinformation,seealso:
• OWASPWebSecurityTestingGuide: TestingforErrorHandling
• OWASPAuthenticationCheatSheetsectionabouterrormessages
• OWASPLoggingCheatSheet
• OWASPApplicationLoggingVocabularyCheatSheet
V17WebRTC
ControlObjective
WebReal‑TimeCommunication(WebRTC)enablesreal‑timevoice,video,anddataexchangeinmod‑
ern applications. As adoption increases, securing WebRTC infrastructure becomes critical. This
section provides security requirements for stakeholders who develop, host, or integrate WebRTC
systems.
TheWebRTCmarketcanbebroadlycategorizedintothreesegments:
1. Product Developers: Proprietary and open‑source vendors that create and supply WebRTC
productsandsolutions. TheirfocusisondevelopingrobustandsecureWebRTCtechnologies
thatcanbeusedbyothers.
2. Communication Platforms as a Service (CPaaS): Providers that offer APIs, SDKs, and the nec‑
essaryinfrastructureorplatformstoenableWebRTCfunctionalities. CPaaSprovidersmayuse
productsfromthefirstcategoryordeveloptheirownWebRTCsoftwaretooffertheseservices.
3. Service Providers: Organizations that leverage products from product developers or CPaaS
providers, or develop their own WebRTC solutions. They create and implement applications
92

ApplicationSecurityVerificationStandard May2025
for online conferencing, healthcare, e‑learning, and other domains where real‑time commu‑
nicationiscrucial.
The security requirements outlined here are primarily focused on Product Developers, CPaaS, and
ServiceProviderswho:
• Utilizeopen‑sourcesolutionstobuildtheirWebRTCapplications.
• UsecommercialWebRTCproductsaspartoftheirinfrastructure.
• Use internally developed WebRTC solutions or integrate various components into a cohesive
serviceoffering.
It is important to notethat these security requirementsdo not apply to developers who exclusively
use SDKs and APIs provided by CPaaS vendors. For such developers, the CPaaS providers are typi‑
callyresponsibleformostoftheunderlyingsecurityconcernswithintheirplatforms,andageneric
securitystandardlikeASVSmaynotfullyaddresstheirneeds.
V17.1TURNServer
ThissectiondefinessecurityrequirementsforsystemsthatoperatetheirownTURN(TraversalUs‑
ingRelaysaroundNAT)servers. TURNserversassistinrelayingmediainrestrictivenetworkenvi‑
ronmentsbutcanposerisksifmisconfigured. Thesecontrolsfocusonsecureaddressfilteringand
protectionagainstresourceexhaustion.
# Description Level
17.1.1 VerifythattheTraversalUsingRelaysaroundNAT(TURN)serviceonly 2
allowsaccesstoIPaddressesthatarenotreservedforspecialpurposes(e.g.,
internalnetworks,broadcast,loopback). NotethatthisappliestobothIPv4
andIPv6addresses.
17.1.2 VerifythattheTraversalUsingRelaysaroundNAT(TURN)serviceisnot 3
susceptibletoresourceexhaustionwhenlegitimateusersattempttoopena
largenumberofportsontheTURNserver.
V17.2Media
TheserequirementsonlyapplytosystemsthathosttheirownWebRTCmediaservers,suchasSelec‑
tiveForwardingUnits(SFUs),MultipointControlUnits(MCUs),recordingservers,orgatewayservers.
Mediaservershandleanddistributemediastreams,makingtheirsecuritycriticaltoprotectcommu‑
nicationbetweenpeers. SafeguardingmediastreamsisparamountinWebRTCapplicationstopre‑
vent eavesdropping, tampering, and denial‑of‑service attacks that could compromise user privacy
andcommunicationquality.
93

ApplicationSecurityVerificationStandard May2025
Inparticular,itisnecessarytoimplementprotectionsagainstfloodattackssuchasratelimiting,val‑
idating timestamps, using synchronized clocks to match real‑time intervals, and managing buffers
topreventoverflowandmaintainpropertiming. Ifpacketsforaparticularmediasessionarrivetoo
quickly,excesspacketsshouldbedropped. Itisalsoimportanttoprotectthesystemfrommalformed
packetsbyimplementinginputvalidation,safelyhandlingintegeroverflows,preventingbufferover‑
flows,andemployingotherrobusterror‑handlingtechniques.
Systemsthatrelysolelyonpeer‑to‑peermediacommunicationbetweenwebbrowsers,withoutthe
involvementofintermediatemediaservers,areexcludedfromthesespecificmedia‑relatedsecurity
requirements.
ThissectionreferstotheuseofDatagramTransportLayerSecurity(DTLS)inthecontextofWebRTC.
Arequirementrelatedtohavingadocumentedpolicyforthemanagementofcryptographickeyscan
be found in the “Cryptography”chapter. Information on approved cryptographic methods can be
found either in the Cryptography Appendix of the ASVS or in documents such as NIST SP 800‑52
Rev.2orBSITR‑02102‑2(Version2025‑01).
# Description Level
17.2.1 VerifythatthekeyfortheDatagramTransportLayerSecurity(DTLS) 2
certificateismanagedandprotectedbasedonthedocumentedpolicyfor
managementofcryptographickeys.
17.2.2 Verifythatthemediaserverisconfiguredtouseandsupportapproved 2
DatagramTransportLayerSecurity(DTLS)ciphersuitesandasecure
protectionprofilefortheDTLSExtensionforestablishingkeysfortheSecure
Real‑timeTransportProtocol(DTLS‑SRTP).
17.2.3 VerifythatSecureReal‑timeTransportProtocol(SRTP)authenticationis 2
checkedatthemediaservertopreventReal‑timeTransportProtocol(RTP)
injectionattacksfromleadingtoeitheraDenialofServiceconditionor
audioorvideomediainsertionintomediastreams.
17.2.4 Verifythatthemediaserverisabletocontinueprocessingincomingmedia 2
trafficwhenencounteringmalformedSecureReal‑timeTransportProtocol
(SRTP)packets.
17.2.5 Verifythatthemediaserverisabletocontinueprocessingincomingmedia 3
trafficduringafloodofSecureReal‑timeTransportProtocol(SRTP)packets
fromlegitimateusers.
17.2.6 Verifythatthemediaserverisnotsusceptibletothe“ClientHello”Race 3
ConditionvulnerabilityinDatagramTransportLayerSecurity(DTLS)by
checkingifthemediaserverispubliclyknowntobevulnerableorby
performingtheraceconditiontest.
94

ApplicationSecurityVerificationStandard May2025
# Description Level
17.2.7 Verifythatanyaudioorvideorecordingmechanismsassociatedwiththe 3
mediaserverareabletocontinueprocessingincomingmediatrafficduring
afloodofSecureReal‑timeTransportProtocol(SRTP)packetsfrom
legitimateusers.
17.2.8 VerifythattheDatagramTransportLayerSecurity(DTLS)certificateis 3
checkedagainsttheSessionDescriptionProtocol(SDP)fingerprintattribute,
terminatingthemediastreamifthecheckfails,toensuretheauthenticityof
themediastream.
V17.3Signaling
ThissectiondefinesrequirementsforsystemsthatoperatetheirownWebRTCsignalingservers. Sig‑
nalingcoordinatespeer‑to‑peercommunicationandmustberesilientagainstattacksthatcoulddis‑
ruptsessionestablishmentorcontrol.
Toensuresecuresignaling,systemsmusthandlemalformedinputsgracefullyandremainavailable
underload.
# Description Level
17.3.1 Verifythatthesignalingserverisabletocontinueprocessinglegitimate 2
incomingsignalingmessagesduringafloodattack. Thisshouldbeachieved
byimplementingratelimitingatthesignalinglevel.
17.3.2 Verifythatthesignalingserverisabletocontinueprocessinglegitimate 2
signalingmessageswhenencounteringmalformedsignalingmessagethat
couldcauseadenialofservicecondition. Thiscouldincludeimplementing
inputvalidation,safelyhandlingintegeroverflows,preventingbuffer
overflows,andemployingotherrobusterror‑handlingtechniques.
References
Formoreinformation,seealso:
• TheWebRTCDTLSClientHelloDoSisbestdocumentedatEnableSecurity’sblogpostaimedat
securityprofessionalsandtheassociatedwhitepaperaimedatWebRTCdevelopers
• RFC3550‑RTP:ATransportProtocolforReal‑TimeApplications
• RFC3711‑TheSecureReal‑timeTransportProtocol(SRTP)
• RFC5764‑DatagramTransportLayerSecurity(DTLS)ExtensiontoEstablishKeysfortheSecure
Real‑timeTransportProtocol(SRTP))
95

ApplicationSecurityVerificationStandard May2025
• RFC8825‑Overview: Real‑TimeProtocolsforBrowser‑BasedApplications
• RFC8826‑SecurityConsiderationsforWebRTC
• RFC8827‑WebRTCSecurityArchitecture
• DTLS‑SRTPProtectionProfiles
AppendixA:Glossary
• AbsoluteMaximumSessionLifetime–Alsoreferredtoas“OverallTimeout”byNIST,thisisthe
maximal amount of time a session can remain active following authentication regardless of
userinteraction. Thisisacomponentofsessionexpiration.
• Allowlist –A list of permitted data or operations, for example, a list of characters that are al‑
lowedtoperforminputvalidation.
• Anti‑forgerytoken –A mechanism by which one or more tokens are passed in a request and
validatedbytheapplicationservertoensurethattherequesthascomefromanexpectedend‑
point.
• Application Security –Application‑level security focuses on the analysis of components that
comprise the application layer of the Open Systems Interconnection Reference Model (OSI
Model), rather than focusing on for example the underlying operating system or connected
networks.
• Application Security Verification –The technical assessment of an application against the
OWASPASVS.
• ApplicationSecurityVerificationReport–Areportthatdocumentstheoverallresultsandsup‑
portinganalysisproducedbytheverifierforaparticularapplication.
• Authentication–Theverificationoftheclaimedidentityofanapplicationuser.
• AutomatedVerification–Theuseofautomatedtools(eitherdynamicanalysistools,staticanal‑
ysistools,orboth)thatusevulnerabilitysignaturestofindproblems.
• Blackboxtesting–Amethodofsoftwaretestingthatexaminesthefunctionalityofanapplica‑
tionwithoutpeeringintoitsinternalstructuresorworkings.
• Common Weakness Enumeration (CWE) –A community‑developed list of common software
securityweaknesses. Itservesasacommonlanguage,ameasuringstickforsoftwaresecurity
tools,andabaselineforweaknessidentification,mitigation,andpreventionefforts.
• Component –A self‑contained unit of code, with associated disk and network interfaces that
communicateswithothercomponents.
• CredentialServiceProvider(CSP)–AlsocalledanIdentityProvider(IdP).Asourceofuserdata
whichmaybeusedasanauthenticationsourcebyotherapplications.
• Cross‑SiteScriptInclusion(XSSI)‑AvariantofCross‑SiteScripting(XSS)attackinwhichaweb
applicationretrievesmaliciouscodefromanexternalresourceandincludesthatcodeaspart
ofitsowncontent.
• Cross‑SiteScripting(XSS)–Asecurityvulnerabilitytypicallyfoundinwebapplicationsallow‑
ingtheinjectionofclient‑sidescriptsintocontent.
96

ApplicationSecurityVerificationStandard May2025
• Cryptographicmodule–Hardware,software,and/orfirmwarethatimplementscryptographic
algorithmsand/orgeneratescryptographickeys.
• Cryptographically secure pseudo‑random number generator (CSPRNG) ‑ A pseudorandom
numbergeneratorwithpropertiesthatmakeitsuitableforuseincryptography,alsoreferred
toasacryptographicrandomnumbergenerator(CRNG).
• Datagram Transport Layer Security (DTLS) –A cryptographic protocol which provides com‑
municationsecurityoveranetworkconnection. ItisbasedontheTLSprotocolbutadaptedfor
protectingdatagram‑orientedprotocols(usuallyoverUDP).DefinedinRFC9147forDTLS1.3.
• Datagram Transport Layer Security Extension to Establish Keys for the Secure Real‑time
TransportProtocol(DTLS‑SRTP)–AmechanismforusingaDTLShandshakeforestablishing
keymaterialforaSRTPsession. DefinedinRFC5764.
• DesignVerification–Thetechnicalassessmentofthesecurityarchitectureofanapplication.
• DynamicApplicationSecurityTesting(DAST)–Technologiesaredesignedtodetectconditions
indicativeofasecurityvulnerabilityinanapplicationinitsrunningstate.
• Dynamic Verification –The use of automated tools that use vulnerability signatures to find
problemsduringtheexecutionofanapplication.
• FastIDentityOnline(FIDO)–Asetofauthenticationstandardsthatallowavarietyofdifferent
authentication methods to be used including biometrics, Trusted Platform Modules (TPMs),
USBsecuritytokens,etc.
• HardwareSecurityModule(HSM)–Hardwarecomponentthatstorescryptographickeysand
othersecretsinaprotectedmanner.
• HibernateQueryLanguage(HQL)–AquerylanguagethatissimilarinappearancetoSQLused
bytheHibernateORMlibrary.
• HTTPStrictTransportSecurity(HSTS)–Anpolicywhichinstructsthebrowsertoonlyconnect
to the domain returning the header via TLS and when a valid certificate is presented. It is
activatedusingtheStrict‑Transport‑Securityresponseheaderfield.
• HyperTextTransferProtocol (HTTP) –An application protocol for distributed, collaborative,
hypermedia information systems. It is the foundation of data communication for the World
WideWeb.
• HyperTextTransferProtocoloverSSL/TLS(HTTPS)–AmethodofsecuringHTTPcommuni‑
cationbyencryptingitusingTransportLayerSecurity(TLS).
• IdentityProvider(IdP)–AlsocalledaCredentialServiceProvider(CSP)inNISTreferences. An
entitythatprovidesanauthenticationsourceforotherapplications.
• Inactivity Timeout –This is the length of time a session can remain active in the absence of
userinteractionwiththeapplication. Thisisacomponentofsessionexpiration.
• InputValidation–Thecanonicalizationandvalidationofuntrusteduserinput.
• JSONWebToken(JWT)–RFC7519definesastandardforaJSONdataobjectmadeupofaheader
sectionwhichexplainshowtovalidatetheobject,abodysectioncontainingasetofclaims,and
asignaturesectionwhichcontainsadigitalsignaturewhichcanbeusedtovalidatethecontents
ofthebodysection. Itisatypeofself‑containedtoken.
• LocalFileInclusion (LFI) ‑ An attack that exploits vulnerable file inclusion procedures in an
97

ApplicationSecurityVerificationStandard May2025
application,leadingtotheinclusionoflocalfilesalreadypresentontheserver.
• MaliciousCode–Codeintroducedintoanapplicationduringitsdevelopmentunbeknownstto
the application owner, which circumvents the application’s intended security policy. Not the
sameasmalwaresuchasavirusorworm!
• Malware –Executable code that is introduced into an application during runtime without the
knowledgeoftheapplicationuseroradministrator.
• Messageauthenticationcode(MAC)‑Acryptographicchecksumondata,computedbyaMAC
generationalgorithm,thatisusedtoprovideassuranceonitsintegrityandauthenticity.
• Multi‑factorauthentication(MFA) –Authenticationwhichincludestwoormoreofthesingle
factors.
• MutualTLS(mTLS)–SeeTLSclientauthentication.
• Object‑relational Mapping (ORM) –A system used to allow a relational/table‑based database
tobereferencedandqueriedwithinanapplicationprogramusinganapplication‑compatible
objectmodel.
• One‑timePassword(OTP)–Apasswordthatisuniquelygeneratedtobeusedonasingleocca‑
sion.
• Open Worldwide Application Security Project (OWASP) –The Open Worldwide Application
SecurityProject(OWASP)isaworldwidefreeandopencommunityfocusedonimprovingthe
security of application software. Our mission is to makeapplication security “visible,”so that
peopleandorganizationscanmakeinformeddecisionsaboutapplicationsecurityrisks. See:
https://www.owasp.org/.
• Password‑Based Key Derivation Function 2 (PBKDF2) –A special one‑way algorithm used to
create a strong cryptographic key from an input text (such as a password) and an additional
randomsaltvalueandcanthereforebeusedtomakeithardertocrackapasswordofflineifthe
resultingvalueisstoredinsteadoftheoriginalpassword.
• PublicKeyInfrastructure(PKI)–Anarrangementthatbindspublickeyswithrespectiveiden‑
tities of entities. The binding is established througha processof registration andissuance of
certificatesatandbyacertificateauthority(CA).
• PublicSwitchedTelephoneNetwork(PSTN)–Thetraditionaltelephonenetworkthatincludes
bothfixed‑linetelephonesandmobiletelephones.
• Real‑timeTransportProtocol(RTP)andReal‑timeTransportControlProtocol(RTCP)–Two
protocolsusedinassociationfortransportingmultimediastreams. UsedbytheWebRTCstack.
DefinedinRFC3550.
• ReferenceToken–Atypeoftokenthatactsasapointeroridentifiertostateormetadatastored
onaserver,sometimesreferredtoasrandomtokensoropaquetokens. Unlikeself‑contained
tokens,whichembedsomeoftheirrelevantdatawithinthetokenitself,referencetokenscon‑
tain no intrinsic information, instead relying on the server for context. The reference token
willeitherbeorcontainasessionidentifier.
• RelyingParty(RP) –Generallyanapplicationwhichisrelyingonauserhavingauthenticated
againstaseparateauthenticationprovider. Theapplicationreliesonsomesortoftokenorset
ofsignedassertionsprovidedbythatauthenticationprovidertotrustthattheuseriswhothey
98

ApplicationSecurityVerificationStandard May2025
saytheyare.
• Remote File Inclusion (RFI) ‑ An attack that exploits vulnerable inclusion procedures in the
application,resultingintheinclusionofremotefiles.
• Scalable Vector Graphics (SVG) –An XML‑based markup language for describing two‑
dimensionalbasedvectorgraphics.
• SecureReal‑timeTransportProtocol(SRTP)andSecureReal‑timeTransportControlProto‑
col(SRTCP) –AprofileoftheRTPandRTCPprotocolsprovidingsupportformessageencryp‑
tion,authenticationandintegrityprotection. DefinedinRFC3711.
• SecurityArchitecture–Anabstractionofanapplication’sdesignthatidentifiesanddescribes
where and how security controls are used, and also identifies and describes the location and
sensitivityofbothuserandapplicationdata.
• SecurityAssertionMarkupLanguage(SAML)–Anopenstandardforsinglesign‑onauthenti‑
cationbasedonpassingsignedassertions(usuallyXMLobjects)betweentheidentityprovider
andtherelyingparty.
• SecurityConfiguration–Theruntimeconfigurationofanapplicationthataffectshowsecurity
controlsareused.
• SecurityControl–Afunctionorcomponentthatperformsasecuritycheck(e.g.,anauthoriza‑
tioncheck)orwhencalledresultsinasecurityeffect(e.g.,generatinganauditrecord).
• Securityinformationandeventmanagement(SIEM)‑Asystemforthreatdetection,compli‑
anceandsecurityincidentmanagementthroughthecollectionandanalysisofsecurity‑related
datafromvarioussourceswithinanorganization’sITinfrastructure.
• Self‑Contained Token –A token that encapsulates one or more attributes that do not rely on
server‑sidestateorotherexternalstorage. Thesetokensensuretheauthenticityandintegrity
oftheircontainedattributes,enablingsecure,“stateless”informationexchangeacrosssystems.
Self‑contained tokens are generally secured using cryptographic techniques, such as digital
signaturesormessageauthenticationcodes(MACs), toensuretheauthenticity, integrity, and
insomecasestheconfidentialityofitsdata. CommonexamplesincludeSAMLAssertionsand
JWTs.
• Server‑sideRequestForgery(SSRF)–Anattackthatabusesfunctionalityontheservertoread
orupdateinternalresources. TheattackersuppliesormodifiesaURL,whichthecoderunning
ontheserverwillreadorsubmitdatato.
• SessionDescriptionProtocol(SDP)–Amessageformatforsettingupmultimediasession(used
forexampleinWebRTC).DefinedinRFC4566.
• Session Identifier or Session ID –A key which identifies a stateful session stored at the back
end. Willbetransferredtoandfromtheclienteitherasorinsidea“ReferenceToken”.
• Session Token –A “catch‑all”phrase used in this standard to refer to the token or value used
in either stateless session mechanisms (which use a self‑contained token) or stateful session
mechanisms(whichuseareferencetoken).
• SessionTraversalUtilitiesforNAT(STUN)–AprotocolusedtoassistNATtraversalinorderto
establishpeer‑to‑peercommunications. DefinedinRFC3489.
• Single‑factorauthenticator–Amechanismtocheckthatauserisauthenticated. Itshouldei‑
99

ApplicationSecurityVerificationStandard May2025
ther be something you know (memorized secrets, passwords, passphrases, PINs), something
you are (biometrics, fingerprint, face scans), or something you have (OTP tokens, a crypto‑
graphicdevicesuchasasmartcard).
• SingleSign‑onAuthentication(SSO)–Thisoccurswhenauserlogsintooneapplicationandis
thenautomaticallyloggedintootherapplicationswithouthavingtore‑authenticate. Forexam‑
ple,whenloggingintoGoogle,theuserwillbeautomaticallyloggedintootherGoogleservices
suchasYouTube,GoogleDocs,andGmail.
• Softwarebillofmaterials(SBOM)‑Astructured,comprehensivelistofallcomponents,mod‑
ules,libraries,frameworksandotherresourcesrequiredtobuildorassembleasoftwareappli‑
cation.
• SoftwareCompositionAnalysis (SCA) –A set of technologies designed to analyze application
composition,dependencies,librariesandpackagesforsecurityvulnerabilitiesofspecificcom‑
ponentversionsinuse. Thisisnottobeconfusedwithsource‑codeanalysiswhichisnowcom‑
monlyreferredtoasSAST.
• Softwaredevelopmentlifecycle(SDLC)–Thestep‑by‑stepprocessbywhichsoftwareisdevel‑
opedgoingfromtheinitialrequirementstodeploymentandmaintenance.
• SQL Injection (SQLi) –A code injection technique used to attack data‑driven applications, in
whichmaliciousSQLstatementsareinsertedintoanentrypoint.
• StatefulSessionMechanism–Inastatefulsessionmechanism,theapplicationretainssession
state at the backend which typically corresponds to a session token, generated using a cryp‑
tographicallysecurepseudo‑randomnumbergenerator(CSPRNG),whichisissuedtotheend
user.
• StatelessSessionMechanism –Astatelesssessionmechanismwilluseaself‑containedtoken
whichispassedtoclients,andcontainssessioninformationthatisnotnecessarilystoredwithin
theservicewhichthenreceivesandvalidatesthetoken. Inreality,aservicewillneedtohave
accesstosomesessioninformation(suchasaJWTrevocationlist)inordertobeabletoenforce
requiredsecuritycontrols.
• Staticapplicationsecuritytesting(SAST) –Asetoftechnologiesdesignedtoanalyzeapplica‑
tionsourcecode,bytecodeandbinariesforcodinganddesignconditionsthatareindicativeof
securityvulnerabilities. SASTsolutionsanalyzeanapplicationfromthe“insideout”inanon‑
runningstate.
• ThreatModeling–Atechniqueconsistingofdevelopingincreasinglyrefinedsecurityarchitec‑
tures to identify threat agents, security zones, security controls, and important technical and
businessassets.
• Time‑of‑check to time‑of‑use (TOCTOU) –A situation where an application checks the state
ofaresourcebeforeusingthatresource,buttheresource’sstatecanbechangedbetweenthe
checkandtheuse. Thiscaninvalidatetheresultsofthecheckandcauseasituationwherethe
applicationperformsinvalidactionsduetothisstatemismatch.
• TimebasedOne‑timePasswords(TOTPs)‑AmethodofgeneratinganOTPwherethecurrent
timeactsaspartofthealgorithmtogeneratethepassword.
• TLS client authentication, also called Mutual TLS (mTLS) –In a standard TLS connection, a
100

ApplicationSecurityVerificationStandard May2025
clientcanusethecertificateprovidedbytheservertovalidatetheserver’sidentity. WhereTLS
clientauthenticationisused,theclientalsousesitsownprivatekeyandcertificatetoallowthe
servertoalsovalidatetheclient’sidentity.
• TransportLayerSecurity (TLS) –Cryptographic protocols that provide communication secu‑
rityoveranetworkconnection.
• TraversalUsingRelaysaroundNAT(TURN)–AnextensionoftheSTUNprotocolusingaTURN
serverasarelaywhendirectpeer‑to‑peerconnectionscannotbeestablished. DefinedinRFC
8656.
• Trustedexecutionenvironment(TEE)‑Anisolatedprocessingenvironmentinwhichapplica‑
tionscanbesecurelyexecutedirrespectiveoftherestofthesystem.
• TrustedPlatformModule(TPM)–AtypeofHSMthatisusuallyattachedtoalargerhardware
componentsuchasamotherboardandactsasthe“rootoftrust”forthatsystem.
• TrustedServiceLayer–Anytrustedcontrolenforcementpoint,suchasamicroservice,server‑
lessAPI,server‑side,atrustedAPIonaclientdevicethathassecureboot,partnerorexternal
APIs,andsoon. Trustedmeansthatthereisnoconcernthatanuntrusteduserwillbeableto
bypassorskipthelayerorcontrolsimplementedatthatlayer.
• Uniform Resource Identifier (URI)‑ A unique string of characters that identifies a resource,
suchaswebpage,mailaddress,places.
• UniformResourceLocator(URL)–AstringthatspecifiesthelocationofresourceontheInter‑
net.
• UniversallyUniqueIdentifier(UUID)–Auniquereferencenumberusedasanidentifierinsoft‑
ware.
• Verifier–ThepersonorteamthatisreviewinganapplicationagainsttheOWASPASVSrequire‑
ments.
• WebReal‑TimeCommunication(WebRTC)–AprotocolstackandassociatedwebAPIusedfor
thetransportofmultimediastreamsinwebapplications,usuallyinthecontextofteleconfer‑
encing. BasedonSRTP,SRTCP,DTLS,SDPandSTUN/TURN.
• WebSocket over TLS (WSS) –A practice of securing WebSocket communication by layering
WebSocketoverTLSprotocol.
• WhatYouSeeIsWhatYouGet(WYSIWYG)–Atypeofrichcontenteditorthatshowshowthe
content will actually look when rendered rather than showing the coding used to govern the
rendering.
• X.509Certificate –AnX.509certificateisadigitalcertificatethatusesthewidelyacceptedin‑
ternationalX.509publickeyinfrastructure(PKI)standardtoverifythatapublickeybelongsto
theuser,computerorserviceidentitycontainedwithinthecertificate.
• XMLeXternalEntity(XXE)–AtypeofXMLentitythatcanaccesslocalorremotecontentviaa
declaredsystemidentifier. Thismayleadtovariousinjectionattacks.
101

ApplicationSecurityVerificationStandard May2025
AppendixB:References
ThefollowingOWASPprojectsaremostlikelytobeusefultousers/adoptersofthisstandard:
OWASPCoreProjects
1. OWASPTop10Project: https://owasp.org/www‑project‑top‑ten/
2. OWASP Web Security Testing Guide: https://owasp.org/www‑project‑web‑security‑testing‑
guide/
3. OWASPProactiveControls: https://owasp.org/www‑project‑proactive‑controls/
4. OWASPSoftwareAssuranceMaturityModel(SAMM):https://owasp.org/www‑project‑samm/
5. OWASPSecureHeadersProject: https://owasp.org/www‑project‑secure‑headers/
OWASPCheatSheetSeriesproject
ThisprojecthasseveralcheatsheetsthatwillberelevanttodifferenttopicsintheASVS.
ThereisamappingtotheASVSwhichcanbefoundhere: https://cheatsheetseries.owasp.org/Index
ASVS.html
MobileSecurityRelatedProjects
1. OWASPMobileSecurityProject: https://owasp.org/www‑project‑mobile‑security/
2. OWASPMobileTop10Risks: https://owasp.org/www‑project‑mobile‑top‑10/
3. OWASPMobileSecurityTestingGuideandMobileApplicationSecurityVerificationStandard:
https://owasp.org/www‑project‑mobile‑security‑testing‑guide/
OWASPInternetofThingsrelatedprojects
1. OWASPInternetofThingsProject: https://owasp.org/www‑project‑internet‑of‑things/
OWASPServerlessprojects
1. OWASPServerlessProject: https://owasp.org/www‑project‑serverless‑top‑10/
Others
Similarly,thefollowingwebsitesaremostlikelytobeusefultousers/adoptersofthisstandard
1. SecListsGithub: https://github.com/danielmiessler/SecLists
2. MITRECommonWeaknessEnumeration: https://cwe.mitre.org/
102

ApplicationSecurityVerificationStandard May2025
3. PCISecurityStandardsCouncil: https://www.pcisecuritystandards.org/
4. PCI Data Security Standard (DSS) v3.2.1 Requirements and Security Assessment Procedures:
https://www.pcisecuritystandards.org/documents/PCI_DSS_v3‑2‑1.pdf
5. PCISoftwareSecurityFramework‑SecureSoftwareRequirementsandAssessmentProcedures:
https://www.pcisecuritystandards.org/documents/PCI‑Secure‑Software‑Standard‑v1_0.pdf
6. PCISecureSoftwareLifecycle(SecureSLC)RequirementsandAssessmentProcedures: https:
//www.pcisecuritystandards.org/documents/PCI‑Secure‑SLC‑Standard‑v1_0.pdf
7. OWASP ASVS 4.0 Testing Guide https://github.com/BlazingWind/OWASP‑ASVS‑4.0‑testing‑
guide
AppendixC:CryptographyStandards
The “Cryptography”chapter goes beyond simply defining best practices. It aims to enhance under‑
standingofcryptographyprinciplesandencouragetheadoptionofmoreresilient,modernsecurity
methods. Thisappendixprovidesdetailedtechnicalinformationregardingeachrequirement,com‑
plementingtheoverarchingstandardsoutlinedinthe“Cryptography”chapter.
Thisappendixdefinesthelevelofapprovalfordifferentcryptographicmechanisms:
• Approved(A)mechanismscanbeusedinapplications.
• Legacymechanisms(L)shouldnotbeusedinapplicationsbutmightstillbeusedforcompati‑
bilitywithexistinglegacyapplicationsorcodeonly. Whiletheusageofsuchthesemechanisms
iscurrentlynotconsideredtobeavulnerabilityinitself,theyshouldbereplacedbymorese‑
cureandfuture‑proofmechanismsassoonaspossible.
• Disallowedmechanisms(D)mustnotbeusedbecausetheyarecurrentlyconsideredbrokenor
donotprovidesufficientsecurity.
Thislistmaybeoverriddeninthecontextofagivenapplicationforvariousreasonsincluding:
• newevolutionsinthefieldofcryptography;
• compliancewithregulation.
CryptographicInventoryandDocumentation
This section provides additional information for V11.1 Cryptographic Inventory and Documenta‑
tion.
Itisimportanttoensurethatallcryptographicassets,suchasalgorithms,keys,andcertificates,are
regularlydiscovered,inventoried,andassessed. ForLevel3,thisshouldincludetheuseofstaticand
dynamicscanningtodiscovertheuseofcryptographyinanapplication. ToolssuchasSASTandDAST
mayhelpwiththisbutitispossiblethatdedicatedtoolswouldbeneededtogetmorecomprehensive
coverage. Freewareexamplesoftoolsinclude:
• CryptoMon‑NetworkCryptographyMonitor‑usingeBPF,writteninpython
103

ApplicationSecurityVerificationStandard May2025
• CryptobomForgeTool: GeneratingComprehensiveCBOMsfromCodeQLOutputs
EquivalentStrengthsofCryptographicParameters
Therelativesecuritystrengthsforvariouscryptographicsystemsareinthistable(fromNISTSP800‑
57Part1,p.71):
|     | SymmetricKey |     | Integer |     |
| --- | ------------ | --- | ------- | --- |
SecurityStrength Algorithms FiniteField Factorization EllipticCurve
| <=80 | 2TDEA   | L=1024N=160  | k=1024  | f=160‑223 |
| ---- | ------- | ------------ | ------- | --------- |
| 112  | 3TDEA   | L=2048N=224  | k=2048  | f=224‑255 |
| 128  | AES‑128 | L=3072N=256  | k=3072  | f=256‑383 |
| 192  | AES‑192 | L=7680N=384  | k=7680  | f=384‑511 |
| 256  | AES‑256 | L=15360N=512 | k=15360 | f=512+    |
Exampleofapplications:
| • FiniteFieldCryptography:          | DSA,FFDH,MQV         |     |     |     |
| ----------------------------------- | -------------------- | --- | --- | --- |
| • IntegerFactorizationCryptography: |                      | RSA |     |     |
| • EllipticCurveCryptography:        | ECDSA,EdDSA,ECDH,MQV |     |     |     |
Note: that this section assumes that no quantum computer exists; if such a computer would exist,
theestimatesforthelast3columnswouldbenolongervalid.
RandomValues
ThissectionprovidesadditionalinformationforV11.5RandomValues.
| Name        | Version/Reference       |     | Notes                 | Status |
| ----------- | ----------------------- | --- | --------------------- | ------ |
| /dev/random | Linux4.8+(Oct2016),also |     | UtilizingChaCha20     | A      |
|             | foundiniOS,Android,and  |     | stream. FoundiniOS    |        |
|             | otherLinux‑basedPOSIX   |     | SecRandomCopyBytesand |        |
AndroidSecure Random
|     | operatingsystems. | Based |                        |     |
| --- | ----------------- | ----- | ---------------------- | --- |
|     | onRFC7539         |       | withthecorrectsettings |     |
providedtoeach.
/dev/urandom Linuxkernel’sspecialfile Provideshigh‑quality, A
|     | forprovidingrandomdata |     | entropysourcesfrom |     |
| --- | ---------------------- | --- | ------------------ | --- |
hardwarerandomness
104

| ApplicationSecurityVerificationStandard |                   |     |                | May2025 |
| --------------------------------------- | ----------------- | --- | -------------- | ------- |
| Name                                    | Version/Reference |     | Notes          | Status  |
| AES-CTR-DRBG                            | NISTSP800‑90A     |     | Asusedincommon | A       |
implementations,suchas
WindowsCNGAPI
BCryptGenRandomsetby
BCRYPT_RNG_ALGORITHM.
| HMAC-DRBG | NISTSP800‑90A |     |     | A   |
| --------- | ------------- | --- | --- | --- |
| Hash-DRBG | NISTSP800‑90A |     |     | A   |
getentropy()
|     | OpenBSD,availablein |     | Providessecurerandom  | A   |
| --- | ------------------- | --- | --------------------- | --- |
|     | Linuxglibc2.25+and  |     | bytesdirectlyfromthe  |     |
|     | macOS10.12+         |     | kernel’sentropysource |     |
withastraightforwardand
minimalAPI.It’smore
modernandavoidspitfalls
associatedwitholderAPIs.
TheunderlyinghashfunctionusedwithHMAC‑DRBGorHash‑DRBGmustbeapprovedforthisus‑
age.
CipherAlgorithms
ThissectionprovidesadditionalinformationforV11.3EncryptionAlgorithms.
Approvedcipheralgorithmsarelistedinorderofpreference.
| SymmetricKeyAlgorithms |     | Reference                |     | Status |
| ---------------------- | --- | ------------------------ | --- | ------ |
| AES‑256                |     | FIPS197                  |     | A      |
| Salsa20                |     | Salsa20specification     |     | A      |
| XChaCha20              |     | XChaCha20Draft           |     | A      |
| XSalsa20               |     | ExtendingtheSalsa20nonce |     | A      |
| ChaCha20               |     | RFC8439                  |     | A      |
| AES‑192                |     | FIPS197                  |     | A      |
| AES‑128                |     | FIPS197                  |     | L      |
| 2TDEA                  |     |                          |     | D      |
| TDEA(3DES/3DEA)        |     |                          |     | D      |
105

| ApplicationSecurityVerificationStandard |     |           |     | May2025 |
| --------------------------------------- | --- | --------- | --- | ------- |
| SymmetricKeyAlgorithms                  |     | Reference |     | Status  |
| IDEA                                    |     |           |     | D       |
| RC4                                     |     |           |     | D       |
| Blowfish                                |     |           |     | D       |
| ARC4                                    |     |           |     | D       |
| DES                                     |     |           |     | D       |
AESCipherModes
Block ciphers, such as AES, can be used with different modes of operations. Many modes of oper‑
ations, suchasElectroniccodebook(ECB),areinsecureandmustnotbeused. TheGalois/Counter
Mode(GCM)andCounterwithcipherblockchainingmessageauthenticationcode(CCM)modesof
operationsprovideauthenticatedencryptionandshouldbeusedinmodernapplications.
Approvedmodesarelistedinorderofpreference.
| Mode  | Authenticated | Reference     | Status | Restriction |
| ----- | ------------- | ------------- | ------ | ----------- |
| GCM   | Yes           | NISTSP800‑38D | A      |             |
| CCM   | Yes           | NISTSP800‑38C | A      |             |
| CBC   | No            | NISTSP800‑38A | L      |             |
| CCM‑8 | Yes           |               | D      |             |
| ECB   | No            |               | D      |             |
| CFB   | No            |               | D      |             |
| OFB   | No            |               | D      |             |
| CTR   | No            |               | D      |             |
Notes:
• Allencryptedmessagesmustbeauthenticated. ForANYuseofCBCmodethereMUSTbean
associatedhashingMACalgorithmtovalidatethemessage. Ingeneral,thisMUSTbeappliedin
the Encrypt‑Then‑Hash method (but TLS 1.2 uses Hash‑Then‑Encrypt instead). If this cannot
beguaranteed,thenCBCMUSTNOTbeused. Theonlyapplicationwhereencryptionwithout
aMACalgorithmisallowedisdiskencryption.
• IfCBCisused,itshallbeguaranteedthattheverificationofthepaddingisperformedincon‑
stanttime.
106

ApplicationSecurityVerificationStandard May2025
• WhenusingCCM‑8,theMACtagonlyhas64bitsofsecurity. Thisdoesnotconformtorequire‑
ment6.2.9whichrequiresatleast128bitsofsecurity.
• DiskencryptionisconsideredoutofscopefortheASVS.Thereforethisappendixdoesnotlist
anyapprovedmethodfordiskencryption. Forthisusage,encryptionwithoutauthenticationis
usuallyacceptedandtheXTS,XEXandLRWmodesaretypicallyused.
KeyWrapping
Cryptographickeywrap(andcorrespondingkeyunwrap)isamethodofprotectinganexistingkey
by encapsulating (i.e., wrapping) it by employing an additional encryption mechanism so that the
originalkeyisnotobviouslyexposed,e.g.,duringatransfer. Thisadditionalkeyusedtoprotectthe
originalkeyisreferredtoasthewrapkey.
Thisoperationmaybeperformedwhenitisdesirabletoprotectkeysinplacesdeemeduntrustwor‑
thy,ortosendsensitivekeysoveruntrustednetworksorwithinapplications. However,seriouscon‑
sideration should be given to understanding the nature (e.g., the identity and the purpose) of the
original key prior to committing to a wrap/unwrap procedure as this may have repercussions for
both source and target systems/applications in terms of security and especially compliance which
mayincludeaudittrailsofakey’sfunction(e.g.,signing)aswellasappropriatekeystorage.
Specifically, AES‑256 MUST be used for key wrapping, following NIST SP 800‑38F and considering
forward‑lookingprovisionsagainstthequantumthreat. CiphermodesusingAESarethefollowing,
inorderofpreference:
KeyWrapping Reference Status
KW NISTSP800‑38F A
KWP NISTSP800‑38F A
AES‑192andAES‑128MAYbeusediftheusecasedemandsit,butitsmotivationMUSTbedocumented
intheentity’scryptographyinventory.
AuthenticatedEncryption
Withtheexceptionofdiskencryption,encrypteddatamustbeprotectedagainstunauthorizedmod‑
ificationusingsomeformofauthenticatedencryption(AE)scheme,usuallyusinganauthenticated
encryptionwithassociateddata(AEAD)scheme.
TheapplicationshouldpreferablyuseanapprovedAEADscheme. Itmightalternativelycombinean
approvedcipherschemeandanapprovedMACalgorithmwithaEncrypt‑then‑MACconstruct.
MAC‑then‑encrypt is still allowed for compatibility with legacy applications. It is used in TLS v1.2
witholdcipherssuites.
107

| ApplicationSecurityVerificationStandard |           |     | May2025 |
| --------------------------------------- | --------- | --- | ------- |
| AEADmechanism                           | Reference |     | Status  |
| AES‑GCM                                 | SP800‑38D |     | A       |
| AES‑CCM                                 | SP800‑38C |     | A       |
| ChaCha‑Poly1305                         | RFC7539   |     | A       |
AEGIS‑256 AEGIS:AFastAuthenticatedEncryptionAlgorithm(v1.1) A
AEGIS‑128 AEGIS:AFastAuthenticatedEncryptionAlgorithm(v1.1) A
AEGIS‑128L AEGIS:AFastAuthenticatedEncryptionAlgorithm(v1.1) A
| Encrypt‑then‑MAC |     |     | A   |
| ---------------- | --- | --- | --- |
| MAC‑then‑encrypt |     |     | L   |
HashFunctions
ThissectionprovidesadditionalinformationforV11.4HashingandHash‑basedFunctions.
HashFunctionsforGeneralUseCases
Thefollowingtablelistshashfunctionsapprovedingeneralcryptographicusecasessuchasdigital
signatures:
• Approvedhashfunctionsprovidestrongcollisionresistanceandaresuitableforhigh‑security
applications.
• Some of these algorithms offer strong resistance to attacks when used with proper crypto‑
graphic key management, and so are additionally approved for HMAC, KDF, and RBG func‑
tions.
• Hash function with less than 254 bit of output have insufficient collision resistance and must
notbeusedfordigitalsignatureorotherapplicationsrequiringcollisionresistance. Forother
usages, they might be used for compatibility and verification ONLY with legacy systems but
mustnotbeusedinnewdesigns.
| Hashfunction | Reference | Status Restrictions |     |
| ------------ | --------- | ------------------- | --- |
| SHA3‑512     | FIPS202   | A                   |     |
| SHA‑512      | FIPS180‑4 | A                   |     |
| SHA3‑384     | FIPS202   | A                   |     |
| SHA‑384      | FIPS180‑4 | A                   |     |
| SHA3‑256     | FIPS202   | A                   |     |
108

| ApplicationSecurityVerificationStandard |                                |                     | May2025 |
| --------------------------------------- | ------------------------------ | ------------------- | ------- |
| Hashfunction                            | Reference                      | Status Restrictions |         |
| SHA‑512/256                             | FIPS180‑4                      | A                   |         |
| SHA‑256                                 | FIPS180‑4                      | A                   |         |
| SHAKE256                                | FIPS202                        | A                   |         |
| BLAKE2s                                 | BLAKE2: simpler,smaller,fastas | A                   |         |
MD5
| BLAKE2b | BLAKE2: simpler,smaller,fastas | A   |     |
| ------- | ------------------------------ | --- | --- |
MD5
| BLAKE3 | BLAKE3onefunction,fast | A   |     |
| ------ | ---------------------- | --- | --- |
everywhere
| SHA‑224 | FIPS180‑4 | L NotsuitableforHMAC,KDF, |     |
| ------- | --------- | ------------------------- | --- |
RBG,digitalsignatures
| SHA‑512/224 | FIPS180‑4 | L NotsuitableforHMAC,KDF, |     |
| ----------- | --------- | ------------------------- | --- |
RBG,digitalsignatures
| SHA3‑224 | FIPS202 | L NotsuitableforHMAC,KDF, |     |
| -------- | ------- | ------------------------- | --- |
RBG,digitalsignatures
| SHA‑1 | RFC3174&RFC6194 | L NotsuitableforHMAC,KDF, |     |
| ----- | --------------- | ------------------------- | --- |
RBG,digitalsignatures
| CRC(anylength) |         | D   |     |
| -------------- | ------- | --- | --- |
| MD4            | RFC1320 | D   |     |
| MD5            | RFC1321 | D   |     |
HashFunctionsforPasswordStorage
For secure password hashing, dedicated hash functions must be used. These slow‑hashing algo‑
rithmsmitigatebrute‑forceanddictionaryattacksbyincreasingthecomputationaldifficultyofpass‑
wordcracking.
| KDF      | Reference | RequiredParameters      | Status |
| -------- | --------- | ----------------------- | ------ |
| argon2id | RFC9106   | t=1: m≥47104(46MiB),p=1 | A      |
|          |           | t=2: m≥19456(19MiB),p=1 | A      |
|          |           | t≥3: m≥12288(12MiB),p=1 | A      |
| scrypt   | RFC7914   | p=1: N≥2^17(128MiB),r=8 | A      |
109

| ApplicationSecurityVerificationStandard |                   |                        | May2025 |
| --------------------------------------- | ----------------- | ---------------------- | ------- |
| KDF                                     | Reference         | RequiredParameters     | Status  |
|                                         |                   | p=2: N≥2^16(64MiB),r=8 | A       |
|                                         |                   | p≥3: N≥2^15(32MiB),r=8 | A       |
| bcrypt                                  | AFuture‑Adaptable | cost≥10                | A       |
PasswordScheme
| PBKDF2‑HMAC‑SHA‑512 | NISTSP800‑132,FIPS | iterations≥210,000 | A   |
| ------------------- | ------------------ | ------------------ | --- |
180‑4
| PBKDF2‑HMAC‑SHA‑256 | NISTSP800‑132,FIPS | iterations≥600,000 | A   |
| ------------------- | ------------------ | ------------------ | --- |
180‑4
| PBKDF2‑HMAC‑SHA‑1 | NISTSP800‑132,FIPS | iterations≥1,300,000 | L   |
| ----------------- | ------------------ | -------------------- | --- |
180‑4
Approvedpassword‑basedkeyderivationsfunctionscanbeusedforpasswordstorage.
KeyDerivationFunctions(KDFs)
GeneralKeyDerivationFunctions
| KDF             |     | Reference       | Status |
| --------------- | --- | --------------- | ------ |
| HKDF            |     | RFC5869         | A      |
| TLS1.2PRF       |     | RFC5248         | L      |
| MD5‑basedKDFs   |     | RFC1321         | D      |
| SHA‑1‑basedKDFs |     | RFC3174&RFC6194 | D      |
Password‑basedKeyDerivationFunctions
| KDF      | Reference | RequiredParameters      | Status |
| -------- | --------- | ----------------------- | ------ |
| argon2id | RFC9106   | t=1: m≥47104(46MiB),p=1 | A      |
|          |           | t=2: m≥19456(19MiB),p=1 | A      |
| scrypt   | RFC7914   | p=1: N≥2^17(128MiB),r=8 | A      |
|          |           | p=2: N≥2^16(64MiB),r=8  | A      |
|          |           | p≥3: N≥2^15(32MiB),r=8  | A      |
110

| ApplicationSecurityVerificationStandard |                    |                    |     | May2025 |
| --------------------------------------- | ------------------ | ------------------ | --- | ------- |
| KDF                                     | Reference          | RequiredParameters |     | Status  |
| PBKDF2‑HMAC‑SHA‑512                     | NISTSP800‑132,FIPS | iterations≥210,000 |     | A       |
180‑4
| PBKDF2‑HMAC‑SHA‑256 | NISTSP800‑132,FIPS | iterations≥600,000 |     | A   |
| ------------------- | ------------------ | ------------------ | --- | --- |
180‑4
| PBKDF2‑HMAC‑SHA‑1 | NISTSP800‑132,FIPS | iterations≥1,300,000 |     | L   |
| ----------------- | ------------------ | -------------------- | --- | --- |
180‑4
KeyExchangeMechanisms
ThissectionprovidesadditionalinformationforV11.6PublicKeyCryptography.
KEXSchemes
A security strength of 112 bits or above MUST be ensured for all Key Exchange schemes, and their
implementationMUSTfollowtheparameterchoicesinthefollowingtable.
| Scheme                                  |     | DomainParameters | ForwardSecrecy | Status |
| --------------------------------------- | --- | ---------------- | -------------- | ------ |
| FiniteFieldDiffie‑Hellman(FFDH)         |     | L>=3072&N>=256   | Yes            | A      |
| EllipticCurveDiffie‑Hellman(ECDH)       |     | f>=256‑383       | Yes            | A      |
| EncryptedkeytransportwithRSA‑PKCS#1v1.5 |     |                  | No             | D      |
Wherethefollowingparametersare:
• kisthekeysizeforRSAkeys.
• ListhesizeofthepublickeyandNisthesizeoftheprivatekeyforfinitefieldcryptography.
• fistherangeofkeysizesforECC.
AnynewimplementationMUSTNOTuseanyschemethatisNOTcompliantwithNISTSP800‑56A&
BandNISTSP800‑77. Specifically,IKEv1MUSTNOTbeusedinproduction.
Diffie‑Hellmangroups
The following groups are approved for implementations of Diffie‑Hellman key exchange. Security
strengthsaredocumentedinNISTSP800‑56A,AppendixD,andNISTSP800‑57Part1Rev.5.
111

ApplicationSecurityVerificationStandard May2025
Group Status
P‑224,secp224r1 A
P‑256,secp256r1 A
P‑384,secp384r1 A
P‑521,secp521r1 A
K‑233,sect233k1 A
K‑283,sect283k1 A
K‑409,sect409k1 A
K‑571,sect571k1 A
B‑233,sect233r1 A
B‑283,sect283r1 A
B‑409,sect409r1 A
B‑571,sect571r1 A
Curve448 A
Curve25519 A
MODP‑2048 A
MODP‑3072 A
MODP‑4096 A
MODP‑6144 A
MODP‑8192 A
ffdhe2048 A
ffdhe3072 A
ffdhe4096 A
ffdhe6144 A
ffdhe8192 A
MessageAuthenticationCodes(MAC)
MessageAuthenticationCodes(MACs)arecryptographicconstructsusedtoverifytheintegrityand
authenticityofamessage. AMACtakesamessageandasecretkeyasinputsandproducesafixed‑
sizetag(theMACvalue). MACsarewidelyusedinsecurecommunicationprotocols(e.g.,TLS/SSL)to
ensurethatmessagesexchangedbetweenpartiesareauthenticandintact.
112

| ApplicationSecurityVerificationStandard |                                           | May2025 |
| --------------------------------------- | ----------------------------------------- | ------- |
| MACAlgorithm                            | Reference                                 | Status  |
| HMAC‑SHA‑256                            | RFC2104&FIPS198‑1                         | A       |
| HMAC‑SHA‑384                            | RFC2104&FIPS198‑1                         | A       |
| HMAC‑SHA‑512                            | RFC2104&FIPS198‑1                         | A       |
| KMAC128                                 | NISTSP800‑185                             | A       |
| KMAC256                                 | NISTSP800‑185                             | A       |
| BLAKE3(keyed_hashmode)                  | BLAKE3onefunction,fasteverywhere          | A       |
| AES‑CMAC                                | RFC4493&NISTSP800‑38B                     | A       |
| AES‑GMAC                                | NISTSP800‑38D                             | A       |
| Poly1305‑AES                            | ThePoly1305‑AESmessage‑authenticationcode | A       |
| HMAC‑SHA‑1                              | RFC2104&FIPS198‑1                         | L       |
| HMAC‑MD5                                | RFC1321                                   | D       |
DigitalSignatures
SignatureschemesMUSTuseapprovedkeysizesandparametersperNISTSP800‑57Part1.
| SignatureAlgorithm          | Reference | Status |
| --------------------------- | --------- | ------ |
| EdDSA(Ed25519,Ed448)        | RFC8032   | A      |
| XEdDSA(Curve25519,Curve448) | XEdDSA    | A      |
| ECDSA(P‑256,P‑384,P‑521)    | FIPS186‑4 | A      |
| RSA‑RSSA‑PSS                | RFC8017   | A      |
| RSA‑SSA‑PKCS#1v1.5          | RFC8017   | D      |
| DSA(anykeysize)             | FIPS186‑4 | D      |
Post‑QuantumEncryptionStandards
Post‑quantumcryptography(PQC)implementationsshouldfollowFIPS‑203,FIPS‑204,andFIPS‑205.
At this time, there are not many hardened code examples or reference implementations available
forthesestandards. Forfurtherdetails,seetheNISTannouncementofthefirstthreefinalizedpost‑
quantumencryptionstandards(August2024).
The proposed mlkem768x25519 post‑quantum hybrid TLS key agreement method is supported by
majorbrowserssuchasFirefoxrelease132andChromerelease131. Itmaybeusedincryptographic
113

ApplicationSecurityVerificationStandard May2025
testingenvironmentsorwhenavailablewithinindustry‑orgovernment‑approvedlibraries.
AppendixD:Recommendations
Introduction
Whilstpreparingversion5.0oftheApplicationSecurityVerificationStandard(ASVS),itbecameclear
thattherewereanumberofexistingandnewlysuggesteditemsthatshouldn’tbeincludedasrequire‑
mentsin5.0. ThismayhavebeenbecausetheywerenotinscopeforASVSasperthedefinitionfor
5.0oralternativelyitwasfeltthatwhiletheywereagoodidea,theycouldnotbemademandatory.
Notwantingtolosealltheseitemsentirely,somehavebeencapturedinthisappendix.
Recommended,in‑scopemechanisms
The following items are in‑scope for ASVS. They should not be made mandatory but it is strongly
recommendedtoconsiderthemaspartofasecureapplication.
• Apasswordstrengthmetershouldprovidedtohelpuserssetastrongerpassword.
• Createapubliclyavailablesecurity.txtfileattherootor.well‑knowndirectoryoftheapplication
thatclearlydefinesalinkore‑mailaddressforpeopletocontactownersaboutsecurityissues.
• Client‑side input validation should be enforced in addition to validation at a trusted service
layerasthisprovidesagoodopportunitytodiscoverwhensomeonehasbypassedclient‑side
controlsinanattempttoattacktheapplication.
• Preventaccidentallyaccessibleandsensitivepagesfromappearinginsearchenginesusinga
robots.txtfile,theX‑Robots‑Tagresponseheaderorarobotshtmlmetatag.
• WhenusingGraphQL,implementauthorizationlogicatthebusinesslogiclayerinsteadofthe
GraphQLorresolverlayertoavoidhavingtohandleauthorizationoneveryseparateinterface.
References:
• Moreinformationonsecurity.txtincludingalinktotheRFC
SoftwareSecurityprinciples
ThefollowingitemswerepreviouslyinASVSbutarenotreallyrequirements. Rathertheyareprin‑
ciplestoconsiderwhenimplementingsecuritycontrolsthatwhenfollowedwillleadtomorerobust
controls. Theseinclude:
• Security controls should be centralized, simple (economy of design), verifiably secure, and
reusable. Thisshouldavoidduplicate,missing,orineffectivecontrols.
• Wherever possible, use previously written and well‑vetted security control implementations
ratherthanrelyingonimplementingcontrolsfromscratch.
114

ApplicationSecurityVerificationStandard May2025
• Ideally, a single access control mechanism should be used to access protected data and re‑
sources. All requests should pass through this single mechanism to avoid copy and paste or
insecurealternativepaths.
• Attributeorfeature‑basedaccesscontrolisarecommendedpatternwherebythecodechecks
theuser’sauthorizationforafeatureordataitemratherthanjusttheirrole. Permissionsshould
stillbeallocatedusingroles.
SoftwareSecurityprocesses
ThereareanumberofsecurityprocesseswhichwereremovedfromASVS5.0butarestillagoodidea.
TheOWASPSAMMprojectmaybeagoodsourceforhowtoeffectivelyimplementtheseprocesses.
TheitemswhichwerepreviouslyinASVSinclude:
• Verify the use of a secure software development lifecycle that addresses security in all stages
ofdevelopment.
• Verifytheuseofthreatmodelingforeverydesignchangeorsprintplanningtoidentifythreats,
planforcountermeasures,facilitateappropriateriskresponses,andguidesecuritytesting.
• Verify that all user stories and features contain functional security constraints, such as “As a
user, Ishouldbeabletoviewandeditmyprofile. Ishouldnotbeabletovieworeditanyone
else’sprofile”
• Verify availability of a secure coding checklist, security requirements, guideline, or policy to
alldevelopersandtesters.
• Verify that an ongoing process exists to ensure that the application source code is free from
backdoors,maliciouscode(e.g.,salamiattacks,logicbombs,timebombs),andundocumented
or hidden features (e.g., Easter eggs, insecure debugging tools). Complying with this section
isnotpossiblewithoutcompleteaccesstosourcecode, includingthird‑partylibraries, andis
thereforeprobablyonlysuitableforapplicationsrequiringtheveryhighestlevelsofsecurity.
• Verify that mechanisms are in place to detect and respond to configuration drift in deployed
environments. This may include using immutable infrastructure, automated redeployment
from a secure baseline, or drift detection tools that compare current state against approved
configurations.
• Verifythatconfigurationhardeningisperformedonallthird‑partyproducts,libraries,frame‑
works,andservicesaspertheirindividualrecommendations.
References:
• OWASPThreatModelingCheatSheet
• OWASPThreatmodeling
• OWASPSoftwareAssuranceMaturityModelProject
• MicrosoftSDL
115

ApplicationSecurityVerificationStandard May2025
AppendixE‑Contributors
We gratefully acknowledge the contributions of the following people who have commented or
openedpullrequestssincethethereleaseofASVS4.0.0.
Ifyouareawareofanymistakesorwouldlikeyournametoappeardifferently,pleaseletusknow.
JohanSydseter luisservin(lfservin) OleksiiDovydkov IZUKAMasahiro
| (sydseter) |     | (oleksiidov) | (maizuka) |
| ---------- | --- | ------------ | --------- |
JamesSulinski EliSaad(ThunderSon) kkshitish9 AndrewvanderStock
| (jsulinski) |     |     | (vanderaj) |
| ----------- | --- | --- | ---------- |
RickM(kingthorin) BankdeEakasit MichaelGargiullo RaphaelDunant
|                      | (Bankde) | (mgargiullo)    | (Racater)       |
| -------------------- | -------- | --------------- | --------------- |
| CesarKohl(cesarkohl) | inaz0    | JoergBruenner   | DavidDeatherage |
|                      |          | (JoergBruenner) | (securitydave)  |
JohnCarroll JimFenton(jimfenton) MatteoPace(M4tteoP) Sebastiengioria
| (yosignals)      |                     |                 | (SPoint42)     |
| ---------------- | ------------------- | --------------- | -------------- |
| StevenvanderBaan | JeremyBonghwan      | craig‑shony     | RiccardoSirigu |
| (vdbaan)         | Choi(jeremychoi)    |                 | (ricsirigu)    |
| TomaszWrobel     | AlenaDubeshko       | RafaelGreen     | mjang‑cobalt   |
| (tw2as)          | (belalena)          | (RafaelGreen1)  |                |
| clallier94       | KevinW.Wall(kwwall) | JordanSherman   | IngoRauner     |
|                  |                     | (jsherm‑fwdsec/ | (ingo‑rauner)  |
deleterepo)
| DirkWetter(drwetter) | MosheZioni         | PatrickDwyer      | DavidClarke      |
| -------------------- | ------------------ | ----------------- | ---------------- |
|                      | (moshe‑apiiro)     | (coderpatros)     | (davidclarke‑au) |
| TakaharuOgasa        | ArkadiiYakovets    | MotoyasuSaburi    | leirn            |
| (takaharuogasa)      | (arkid15r)         | (motoyasu‑saburi) |                  |
| wet‑certitude        | timhemel           | RLThornton        | ThomasBandt      |
|                      |                    | (thornshadow99)   | (aspnetde)       |
| RoelStorms           | JeroenWillemsen    | anonymous‑31      | KamranSaifullah  |
| (roelstorms)         | (commjoen)         |                   | (deFr0ggy)       |
| SteveSpringett       | Spyros(northdpole) | HansHerrera       | Marx314          |
| (stevespringett)     |                    | (hansphp)         |                  |
CarlosAllendes YonahRuss(yruss972) SanderMaijers LubošBretschneider
|     |     | (sanmai‑NL) | (bretik) |
| --- | --- | ----------- | -------- |
116

ApplicationSecurityVerificationStandard May2025
EvaSarafianou AtaSerenataseren SteveThomas(Sc00bz) DominiqueRIGHETTO
| (esarafianou) |     |     | (righettod) |
| ------------- | --- | --- | ----------- |
StevenvanderBaan MichaelVacarella TonimirKisasondi StefanStreichsbier
| (svdb‑ncc) | (Aif4thah)         | (tkisason)  | (streichsbaer) |
| ---------- | ------------------ | ----------- | -------------- |
| hi‑unc1e   | sb3k(starbuck3000) | mario‑platt | DevdattaAkhawe |
(devd)
MichaelGissing JetAnderson(thatsjet) DaveWichers JonnySchnittger
| (scolytus) |     | (davewichers) | (JonnySchnittger) |
| ---------- | --- | ------------- | ----------------- |
SilviaVäli(silviavali) jackgates73 1songb1rd Timur‑(timurozkul)
| GarethHeyes | appills | suvikaartinen | chaals(chaals) |
| ----------- | ------- | ------------- | -------------- |
(hackvertor)
DanielPharos willFarrell(willfarrell) AlinaVasiljeva PaulMcCann
| (AtlasHackert)      |             | (avasiljeva)   | (ismisepaul)   |
| ------------------- | ----------- | -------------- | -------------- |
| Sage(SajjadPourali) | rbsec       | BenediktBauer  | JamesJardine   |
|                     |             | (mastacheata)  | (jamesjardine) |
| MarkBurnett         | dschwarz91  | Cyber‑AppSec   | Tib3rius       |
| (m8urnett)          |             | (Cyber‑AppSec) |                |
| BitnessWise         | damienbod   | JaredMeit      | StefanSeelmann |
| (bitnesswise)       | (damienbod) | (jmeit‑fwdsec) | (sseelmann)    |
BrendanO’Connor AndreiTitov(andrettv) Hans‑PetterFjeld markehack
| (ussjoin)    |               | (atluxity)    |           |
| ------------ | ------------- | ------------- | --------- |
| NeilMadden   | MichaelGeramb | OsamaElnaggar | mackowski |
| (NeilMadden) | (mgeramb)     | (ossie‑git)   |           |
RaviBalla(raviballa) Hazana(hazanasec) DavidMeans AlexanderStein
|                   |                   | (dmeans82)     | (tohch4)             |
| ----------------- | ----------------- | -------------- | -------------------- |
| BaeSenseii        | VincentDeSchutter | SBani(sbani)   | MitsuakiAkiyama      |
| (baesenseii)      | (VincentDS)       |                | (mak1yama)           |
| ChristopherLoessl | victorxm          | MichalRada     | VeereshDevireddy     |
| (hashier)         |                   | (michalradacz) | (drveresh)           |
| MaknaSEO          | darkzero2022      | Liam           | FrankDenis(jedisct1) |
(LiamDobbelaere)
OttoSulin(ottosulin) carllaw6885 AndersJohan RichardFritsch(rfricz)
Holmefjord(aholmis)
| mesutgungor | ScottHelme   | CarloReggiani   | SuyashSrivastava |
| ----------- | ------------ | --------------- | ---------------- |
|             | (ScottHelme) | (carloreggiani) | (suyash5053)     |
117

ApplicationSecurityVerificationStandard May2025
| MarkPotter        | ArjanLamers     | GøranBreivik(gobrtg) | flo‑blg          |
| ----------------- | --------------- | -------------------- | ---------------- |
| (markonweb)       | (alamers)       |                      |                  |
| GuillaumeDéflache | ToufikAirane    | KeithHoodlet         | Sinner           |
| (guillaume‑d)     | (toufik‑airane) | (securingdev)        | (SoftwareSinner) |
iloving JeroenBeckers JoubinJabbari(joubin) yufujioka(fujiokayu)
(TheDauntless)
execjosh(execjosh) AlicjaKario(tomato42) SidneyRibeiro GabrielMarquet
|                   |                    | (srjsoftware)     | (Gby56)             |
| ----------------- | ------------------ | ----------------- | ------------------- |
| DrewSchulz        | bedirhan           | muralito          | RonnieFlathers      |
| (drschulz)        |                    |                   | (ropnop)            |
| PhilippeDeRyck    | Malte(mal33)       | MazeOfThoughts    | AndreasFalk         |
| (philippederyck)  |                    |                   | (andifalk)          |
| Javi(javixeneize) | DanielHahn         | borislav‑c        | RobinWood           |
|                   | (averell23)        |                   | (digininja)         |
| miro2ns           | JanDockx(jandockx) | vipinsaini434     | priyanshukumar397   |
| NatSakimura       | BenjaminHäublein   | unknown‑user‑from | AliRamazan          |
| (sakimura)        | (BenjaminHae)      |                   | TAŞDELEN(alitasdln) |
PedroEscaleira Josh(josh‑hemphill) TimWürtele(SECtim) AviD(avidouglen)
(oEscal)
SheHacksPurple fcerullo‑cycubix HectorEryxParedes IreneMichlin
| (shehackspurple) |     | Camacho(heryxpc) | (irene221b) |
| ---------------- | --- | ---------------- | ----------- |
JonahY‑M(TG‑Techie) DhirajBahroos JefMeijvis(jefmeijvis) IzmaDoesItbeta
(bahroos)
| AbdessamadTEMMAR | sectroyer | SohSatoh(sohsatoh) | regoravalaz |
| ---------------- | --------- | ------------------ | ----------- |
(TmmmmmR)
| james‑t            | AramHovsepyan     | JaimeGomezGarciaSan | ValdiGit01       |
| ------------------ | ----------------- | ------------------- | ---------------- |
| (james‑bitherder)  | (aramhovsepyan)   |                     |                  |
| iwatachan(ishowta) | VinodAnandan      | KevinKien           | paul‑williamson‑ |
|                    | (VinodAnandan)    | (KevinKien)         | swoop            |
| endergzr           | RadhwanAlshamamri | GrantOngers(rewtd)  | Cure53(cure53)   |
(Rado0z)
| AliR2Linux | AdsDawson(Gang‑   | WilliamReyor  | gabe(gcrow)      |
| ---------- | ----------------- | ------------- | ---------------- |
|            | GreenTemperTatum) | (BillReyor)   |                  |
| mascotter  | luissaiz          | SurenManukyan | PiotrGliźniewicz |
|            |                   | (vx‑sec)      | (pglizniewicz)   |
118

ApplicationSecurityVerificationStandard May2025
TadeuszWachowski NasirakaNate settantasette LarsHaulin(LarsH)
| (tadeuszwachowski) | (andesec) |     |     |
| ------------------ | --------- | --- | --- |
TerenceEden(edent) JasmineScholz ArunSivadasan YusufGÜR(yusuffgur)
(teavanist)
| TroyMarshall | TannerPrynn(tprynn) | NickK.(nickific) | raoul361 |
| ------------ | ------------------- | ---------------- | -------- |
(troymarshall)
| AzeemIlyas       | EvoStamatov(avioli) | TimPotter           | GavinRay          |
| ---------------- | ------------------- | ------------------- | ----------------- |
| (TheAxZim)       |                     | (timpotter87)       | (GavinRay97)      |
| monis(demideus)  | MarcinHoppe         | Grambulf(ramshazar) | JordanPike        |
|                  | (MarcinHoppe)       |                     | (computersarebad) |
| JasonRogers      | BenHall(benbhall)   | JamesPoppyCock      | WhiteHackLabs     |
| (jason‑invision) |                     | (jamesly123)        | (whitehacklabs)   |
| AlexGaynor(alex) | FilipvanLaenen      | jeurgen             | GraoMelo          |
(filipvanlaenen)
AndreasKurtz(ay‑kay) TomTervoort oldman(deveras) MarcoSchnüriger
|        | (TomTervoort) |          | (marcortw)   |
| ------ | ------------- | -------- | ------------ |
| stiiin | infoseclearn  | hljupkij | Noe(nmarher) |
(teaminfoseclearn)
Lyz(lyz‑code) MartinRiedel KIMJaesuck(tcaesvk) BarbaraSchachner
|     | (mrtnrdl) |     | (bschach) |
| --- | --------- | --- | --------- |
RenéReuter(AresSec) carhackpils Tyler(tyler2cr) Hugo(hasousa)
| WouterBloeyaert | MarkdeRijk          | Ramin(picohub) | PhilipD.Turner  |
| --------------- | ------------------- | -------------- | --------------- |
| (Someniak)      | (markderijkinfosec) |                | (philipdturner) |
WillChatham(willc)
119
