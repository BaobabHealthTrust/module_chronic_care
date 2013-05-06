P.1. COMPLICATIONS [program: CHRONIC CARE MODULE, label: Complications]
C.1.1. For all patients capture the following lab results
Q.1.1.1. Complication Type Type [pos: 1, concept: Complications]
O.1.1.1.1. Oedema
O.1.1.1.2. Shortness of breath
O.1.1.1.3. Funduscopy
O.1.1.1.4. Creatinine
O.1.1.1.5. MI
O.1.1.1.6. CVA
O.1.1.1.7. Heart Attack
O.1.1.1.8. Stroke
O.1.1.1.9. Amputation
Q.1.1.2. Test year [absoluteMin: 1982, field_type: number, tt_pageStyleClass: NumbersOnlyWithUnknown, condition: __$("1.1.1").value.toLowerCase() != "heart attack" && __$("1.1.1").value.toLowerCase() != "stroke"  && __$("1.1.1").value.toLowerCase() != "amputation", pos: 2]

Q.1.1.3. Test month [tt_pageStyleClass: NumbersOnlyWithUnknown, condition: __$("1.1.1").value.toLowerCase() != "heart attack" && __$("1.1.1").value.toLowerCase() != "stroke"  && __$("1.1.1").value.toLowerCase() != "amputation", pos: 3]

Q.1.1.4. Test day [tt_pageStyleClass: NumbersOnlyWithUnknown, condition: __$("1.1.1").value.toLowerCase() != "heart attack" && __$("1.1.1").value.toLowerCase() != "stroke"  && __$("1.1.1").value.toLowerCase() != "amputation", pos: 4]

