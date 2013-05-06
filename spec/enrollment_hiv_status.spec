P.1. HIV STATUS AT ENROLLMENT [program: CHRONIC CARE MODULE, label: HIV Status]
C.1.1. First visit or if status is unknown or if negative more than 3 months:
Q.1.1.1. HIV Status [concept: HIV Status, pos: 0]
O.1.1.1.1. Negative
O.1.1.1.2. Positive
O.1.1.1.3. Unknown

Q.1.1.3. HIV test year [absoluteMin: 1982, field_type: number, tt_pageStyleClass: NumbersOnlyWithUnknown, condition: __$("1.1.1").value.toLowerCase() != "unknown", pos: 2]

Q.1.1.4. HIV test month [tt_pageStyleClass: NumbersOnlyWithUnknown, condition: __$("1.1.1").value.toLowerCase() != "unknown", pos: 3]

Q.1.1.5. HIV test day [tt_pageStyleClass: NumbersOnlyWithUnknown, condition: __$("1.1.1").value.toLowerCase() != "unknown", pos: 4]

Q.1.1.6. On ART? [pos: 5, concept: on art]
O.1.1.6.1. No
O.1.1.6.2. Yes

Q.1.1.7. On ART? [pos: 6, concept: Patient enrolled in HIV program, condition: __$("1.1.6").value.toLowerCase() == "no"]
O.1.1.7.1. Yes
O.1.1.7.2. No

