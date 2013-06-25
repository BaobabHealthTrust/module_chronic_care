P.1. TREATMENT [program: CHRONIC CARE MODULE, label: Treatment]
C.1.1. For all patients capture the following lab results
Q.1.1.1. Hypertension Category [pos: 1, concept: Complications]
O.1.1.1.1. Mild
O.1.1.1.2. Moderate
O.1.1.1.3. Severe
Q.1.1.2. recommended treatment [pos: 2, concept: recommended treatment]
O.1.1.2.1. Aspirin
O.1.1.2.2. Hydrochlorthiazide 
Q.1.1.3. Advise on Life Changes [pos: 3, concept: advice, condition: __$("1.1.1").value.toLowerCase() == "mild", multiple:true]
O.1.1.3.1. Stop Smoking
O.1.1.3.2. Regular exercises
O.1.1.3.3. Loose weight
O.1.1.3.4. Avoid heavy drinking  
Q.1.1.4. Is current treatment effective? [pos: 4, concept: advice, condition: __$("1.1.1").value.toLowerCase() != "mild"]
O.1.1.4.1. Yes
O.1.1.4.2. No
Q.1.1.5. Refer to Secondary Level? [pos: 5, concept: Refer to Secondary Level?, condition: __$("1.1.1").value.toLowerCase() == "moderate"  &&  __$("1.1.4").value.toLowerCase() == "no"]
O.1.1.5.1. Yes
O.1.1.5.2. No 
Q.1.1.6. Refer to Tertial Level? [pos: 6, concept: Refer to Tertial Level?, condition: __$("1.1.1").value.toLowerCase() == "severe" &&  __$("1.1.4").value.toLowerCase() == "no"]
O.1.1.6.1. Yes
O.1.1.6.2. No
Q.1.1.7. Prescribe Drugs? [pos: 7, concept: Prescribe Drugs]
O.1.1.7.1. Yes
O.1.1.7.2. No
Q.1.1.8. Next Appoinment [pos: 8, concept: Appoinment]
Q.1.1.9. Refer to Secondary Level? [pos: 9, concept: Refer to Secondary Level?, condition: __$("1.1.1").value.toLowerCase() != "moderate"]
O.1.1.9.1. Yes
O.1.1.9.2. No
Q.1.1.10. Referal Reason [pos: 10, concept: Referal Reason, multiple:true, condition: __$("1.1.9").value.toLowerCase() == "yes"]
O.1.1.10.1. SBP > 140 or DBP >= 90 mmHg and aged below 40 years
O.1.1.10.2. SBP > 160 or DBP >= 90 mmHg and aged 40 or more
O.1.1.10.3. BP >= 140 despite treatment
O.1.1.10.4. Diabetic and BP >= 130 inspite tratment
O.1.1.10.5. History of chect pain or exertion
O.1.1.10.6. History of pain in calf
O.1.1.10.7. History of heart attack
O.1.1.10.8. Hsitory of stroke
O.1.1.10.9. Diabetic with ulcers
O.1.1.10.10. Diabetic with numbness and tingling of feet
O.1.1.10.11. Diabetic with severe infection
O.1.1.10.12. Diabetic with poor vision or no eye exam in 2 years
O.1.1.10.13. Positive urine ulbumin
O.1.1.10.14. Persistent or severe breathlessness
O.1.1.10.15. Swelling of legs
O.1.1.10.16. Total cholesterol > 320 mg %
