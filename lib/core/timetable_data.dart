import 'programs_data.dart';

class TimetableEntry {
  final int level;
  final String day;
  final String time;
  final String courseCode;
  final String details;
  final String source;

  const TimetableEntry({
    required this.level,
    required this.day,
    required this.time,
    required this.courseCode,
    required this.details,
    required this.source,
  });
}

String normalizeTimetableCourseCode(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toUpperCase();

final List<TimetableEntry> firstSemester2026Timetable = [
  TimetableEntry(level: 100, day: 'Monday', time: '08:30–11:15', courseCode: 'LAFR1513', details: 'COURSE Title French Language I(All) COURSE Code LAFR1513 Lecture Hall Name of Lecturer Mr. David Tawiah 0242573588', source: 'Business'),
  TimetableEntry(level: 100, day: 'Monday', time: '12:25–15:25', courseCode: 'SOAC 1513', details: 'COURSE Title Principles of Accounting I (BBA, A/C)/ Accounting & Finance I (MGT) COURSE Code SOAC 1513/ SOBF 2613 Lecture Hall Name of Lecturer Mr. Bill Appiah 0551719042', source: 'Business'),
  TimetableEntry(level: 100, day: 'Monday', time: '12:25–15:25', courseCode: 'SOBF 2613', details: 'COURSE Title Principles of Accounting I (BBA, A/C)/ Accounting & Finance I (MGT) COURSE Code SOAC 1513/ SOBF 2613 Lecture Hall Name of Lecturer Mr. Bill Appiah 0551719042', source: 'Business'),
  TimetableEntry(level: 100, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOGE1573', details: 'COURSE Title Studies in African Development (All) COURSE Code SOGE1573 Lecture Hall Name of Lecturer Dr. Josiah Andoh 0208905912', source: 'Business'),
  TimetableEntry(level: 100, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOED1533', details: 'COURSE Title Intro. to Academic Writing (All COURSE Code SOED1533 Lecture Hall Name of Lecturer Mr. Bernard Sam 0201122258', source: 'Business'),
  TimetableEntry(level: 100, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SICS 1573', details: 'COURSE Title Introduction to Programming (Mgt, Psych,A/C)- COURSE Code SICS 1573 Lecture Hall Name of Lecturer Mr. Prince Sackey/Mr. Robert Aidoo 055230881', source: 'Business'),
  TimetableEntry(level: 100, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS 1593', details: 'COURSE Title Intro to Information Technology I (ALL) COURSE Code SICS 1593 Lecture Hall Name of Lecturer Mrs Maame Baawa Osei-Akuamoah 0244758791', source: 'Business'),
  TimetableEntry(level: 200, day: 'Monday', time: '08:30–11:15', courseCode: 'SOMA 1533', details: 'COURSE Title Introduction to Management (MGTA/C) COURSE Code SOMA 1533 Lecture Hall Name of Lecturer Mr. Joseph Tetteh Quaynor 0549222223', source: 'Business'),
  TimetableEntry(level: 200, day: 'Monday', time: '12:25–15:25', courseCode: 'SODB 2523', details: 'COURSE Title Organizational Behaviour (BBA, MGT, A/C)- COURSE Code SODB 2523 Lecture Hall Name of Lecturer Ms. Cathrine Lamptey 0549595566', source: 'Business'),
  TimetableEntry(level: 200, day: 'Thursday', time: '08:30–11:15', courseCode: 'SIMS 3533', details: 'COURSE Title Probability and Statistics (MGT)- COURSE Code SIMS 3533 Lecture Hall Name of Lecturer Mr. William Obeng Amponsah 0241919402 COURSE Title Introductory Finance (BBA) merge with evening stream COURSE Code SOBF 2593 Lecture Hall Name of Lecturer- Bismark Agbeworde 0549036567', source: 'Business'),
  TimetableEntry(level: 200, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOBF 2593', details: 'COURSE Title Probability and Statistics (MGT)- COURSE Code SIMS 3533 Lecture Hall Name of Lecturer Mr. William Obeng Amponsah 0241919402 COURSE Title Introductory Finance (BBA) merge with evening stream COURSE Code SOBF 2593 Lecture Hall Name of Lecturer- Bismark Agbeworde 0549036567', source: 'Business'),
  TimetableEntry(level: 200, day: 'Thursday', time: '12:25–15:25', courseCode: 'SOAC 2723', details: 'COURSE Title Principles of Marketing (BBB, MKTG)- merge with evening COURSE Code SOMA 2513 Lecture Hall Name of Lecturer Mr. Kwame Apau 0504031566 COURSE Title Accountant in Business (A/C)- COURSE Code SOAC 2723(merge with morning stream Lecture Hall Name of Lecturer Michael Sackitey 0543610773', source: 'Business'),
  TimetableEntry(level: 200, day: 'Thursday', time: '12:25–15:25', courseCode: 'SOMA 2513', details: 'COURSE Title Principles of Marketing (BBB, MKTG)- merge with evening COURSE Code SOMA 2513 Lecture Hall Name of Lecturer Mr. Kwame Apau 0504031566 COURSE Title Accountant in Business (A/C)- COURSE Code SOAC 2723(merge with morning stream Lecture Hall Name of Lecturer Michael Sackitey 0543610773', source: 'Business'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SICS 2613', details: 'COURSE Title Programming with Java (MGT:) COURSE Code SICS 2613 Lecture Hall Name of Lecturer Mr. Ebenzer Sowah 0557565095', source: 'Business'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOMA 2533', details: 'COURSE Title Company and Partnership Law I (A/C, MGT) - COURSE Code SOMA 2533 Lecture Hall Name of Lecturer Dr. Samuel Osei Attakora 0546145704 COURSE Title Advanced Business Law-(BBA) merge with evening stream COURSE Code SOMA 2663 Lecture Hall Name of Lecturer Mr. Ogochuku Nweke 0246273798', source: 'Business'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOMA 2663', details: 'COURSE Title Company and Partnership Law I (A/C, MGT) - COURSE Code SOMA 2533 Lecture Hall Name of Lecturer Dr. Samuel Osei Attakora 0546145704 COURSE Title Advanced Business Law-(BBA) merge with evening stream COURSE Code SOMA 2663 Lecture Hall Name of Lecturer Mr. Ogochuku Nweke 0246273798', source: 'Business'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '16:20–Scheduled', courseCode: 'SOAC 2513', details: 'COURSE Title Financial Accounting I (A/C) COURSE Code SOAC 2513 merge with evening stream Lecture Hall Name of Lecture– Mr. Bill Appiah 0551719042', source: 'Business'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SOEC 2623', details: 'COURSE Title Elements of Economics II (MGT, BBA, A/C) COURSE Code SOEC 2623 Lecture Hall Name of Lecturer Dr. George Faah 0205633018', source: 'Business'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS 2553', details: 'COURSE Title Database Mgmt. Systems (A/C, BBA, MGT COURSE Code SICS 2553 Lecture Hall Name of Lecturer- Mr. Snows Quarm 0277400995', source: 'Business'),
  TimetableEntry(level: 300, day: 'Monday', time: '08:30–11:15', courseCode: 'SICS 3652', details: 'COURSE Title E-Commerce & E-Business (MGT)/ SIEC 4513 E-Commerce I (BBA)/ SICS 4763 COURSE Code SICS 3652 Lecture Hall Name of Lecturer - Mr. Frank Adu 0246578556 @ 2 :00PM', source: 'Business'),
  TimetableEntry(level: 300, day: 'Monday', time: '08:30–11:15', courseCode: 'SICS 4763', details: 'COURSE Title E-Commerce & E-Business (MGT)/ SIEC 4513 E-Commerce I (BBA)/ SICS 4763 COURSE Code SICS 3652 Lecture Hall Name of Lecturer - Mr. Frank Adu 0246578556 @ 2 :00PM', source: 'Business'),
  TimetableEntry(level: 300, day: 'Monday', time: '08:30–11:15', courseCode: 'SIEC 4513', details: 'COURSE Title E-Commerce & E-Business (MGT)/ SIEC 4513 E-Commerce I (BBA)/ SICS 4763 COURSE Code SICS 3652 Lecture Hall Name of Lecturer - Mr. Frank Adu 0246578556 @ 2 :00PM', source: 'Business'),
  TimetableEntry(level: 300, day: 'Monday', time: '12:25–15:25', courseCode: 'SOAC 4573', details: 'COURSE Title Taxation (BBA, A/C)- (megre with evening stream COURSE Code SOAC 4573 Lecture Hall Name of Lecturer Mr. Samuel Oku Asamoah 0240546495247', source: 'Business'),
  TimetableEntry(level: 300, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOMA 3643', details: 'COURSE Title Marketing Management (MGT, BBA)- COURSE Code SOMA3533 Lecture Hall Name of Lecturer Ms. Irene Owusu 0208254813 COURSE Title Financial Management I (A/C)- MERGED WITH L400 Mgt COURSE Code Lecture Hall SOMA 3643 Name of Lecturer Mr. Bismark Agbeworde 0549036567', source: 'Business'),
  TimetableEntry(level: 300, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOMA3533', details: 'COURSE Title Marketing Management (MGT, BBA)- COURSE Code SOMA3533 Lecture Hall Name of Lecturer Ms. Irene Owusu 0208254813 COURSE Title Financial Management I (A/C)- MERGED WITH L400 Mgt COURSE Code Lecture Hall SOMA 3643 Name of Lecturer Mr. Bismark Agbeworde 0549036567', source: 'Business'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SOMA 3522', details: 'COURSE TITLE RESEARCH METHODS (ALL)- COURSE CODE SOMA 3522 LECTURE HALL NAME OF LECTURER Mr. Benjamin Zogbator 0208532530 @ 2:00PM', source: 'Business'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOMA 3773', details: 'COURSE Title Managerial Finance I (BBA)- merge with evening stream COURSE Code SOMA 3773 Lecture Hall Name of Lecturer Michael Sackitey 0543610773', source: 'Business'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '16:20–Scheduled', courseCode: 'SOAC 3713', details: 'COURSE Title Management Accounting II (A/C (merge with evening stream COURSE Code SOAC 3713 Lecture Hall Name of Lecturer Mr. Bismark Agbeworde 0549036567', source: 'Business'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SOAC 3733', details: 'COURSE Title Personnel Systems & Procedures (MGT:HR)-merge with evening stream COURSE Code SOMA 3663 Lecture Hall Name of Lecturer Dr. Freda Ocansey 0546738019 COURSE Title Financial Reporting I (A/C (merge with evening stream COURSE Code SOAC 3733 Lecture Hall Name of Lecturer- Mr. Samuel Oku Asamoah 0546495247', source: 'Business'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SOMA 3663', details: 'COURSE Title Personnel Systems & Procedures (MGT:HR)-merge with evening stream COURSE Code SOMA 3663 Lecture Hall Name of Lecturer Dr. Freda Ocansey 0546738019 COURSE Title Financial Reporting I (A/C (merge with evening stream COURSE Code SOAC 3733 Lecture Hall Name of Lecturer- Mr. Samuel Oku Asamoah 0546495247', source: 'Business'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SOMA 3623', details: 'COURSE Title Marketing Research MGT: MKTG (merge with evening stream COURSE Code SOMA 3623 Lecture Hall Name of Lecturer Mr. Samuel Ayeh-Bampoe Mobile: 0555499395', source: 'Business'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '16:20–Scheduled', courseCode: 'SIEC 3533', details: 'COURSE Title E-Commerce Marketing (BBA)- (merge with evening stream COURSE Code SIEC 3533 Lecture Hall Name of Lecturer Mr. Lenos Ankrah 0546682709', source: 'Business'),
  TimetableEntry(level: 400, day: 'Monday', time: '08:30–11:15', courseCode: 'SICS 4733', details: 'COURSE Title Data Communication & Networks (MGT)- COURSE Code SICS 4733 Lecture Hall Name of Lecturer Mr. Ebenzer Sowah 0557565095', source: 'Business'),
  TimetableEntry(level: 400, day: 'Monday', time: '12:25–15:25', courseCode: 'SOAC 4533', details: 'COURSE Title Financial Statement Analysis (BBA (merge with evening stream COURSE Code SOAC 4713 Lecture Hall Name of Lecturer- Mr. Bismark Agbeworde Tel: 0549036567 COURSE Title Govt. & Non-Profit Accounting (A/C)- (merge with evening stream COURSE Code SOAC 4533 Lecture Hall Name of Lecturer Mr. Samuel Oko Asamoah 0546495247', source: 'Business'),
  TimetableEntry(level: 400, day: 'Monday', time: '12:25–15:25', courseCode: 'SOAC 4713', details: 'COURSE Title Financial Statement Analysis (BBA (merge with evening stream COURSE Code SOAC 4713 Lecture Hall Name of Lecturer- Mr. Bismark Agbeworde Tel: 0549036567 COURSE Title Govt. & Non-Profit Accounting (A/C)- (merge with evening stream COURSE Code SOAC 4533 Lecture Hall Name of Lecturer Mr. Samuel Oko Asamoah 0546495247', source: 'Business'),
  TimetableEntry(level: 400, day: 'Monday', time: '16:20–Scheduled', courseCode: 'SIEC 4553', details: 'COURSE Title E-Commerce Cyber Law & Ethics (BBA) (merge with evening stream COURSE Code SIEC 4553 Lecture Hall Name of Lecturer - Dr. Stephen Essel 0262849011 COURSE Title Performance Management (A/C)- (merge with evening stream) COURSE Code SOAC 4773 Lecture Hall Name of Lecturer Mr. Eric Nana Agyemang-Badu 0244694448', source: 'Business'),
  TimetableEntry(level: 400, day: 'Monday', time: '16:20–Scheduled', courseCode: 'SOAC 4773', details: 'COURSE Title E-Commerce Cyber Law & Ethics (BBA) (merge with evening stream COURSE Code SIEC 4553 Lecture Hall Name of Lecturer - Dr. Stephen Essel 0262849011 COURSE Title Performance Management (A/C)- (merge with evening stream) COURSE Code SOAC 4773 Lecture Hall Name of Lecturer Mr. Eric Nana Agyemang-Badu 0244694448', source: 'Business'),
  TimetableEntry(level: 400, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOMA 3513', details: 'COURSE Title Entrepreneurship & Innovation (ALL) COURSE Code SOMA 3513 Lecture Hall Name of Lecturer Nana Yaw Boadi-Appiah 0246543736', source: 'Business'),
  TimetableEntry(level: 400, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SOMA 4683', details: 'COURSE Title Product Mgt (MGT: MKTG) (merge with evening stream COURSE Code SOMA 4683 Lecture Hall Name of Lecturer Ms. Irene Owusu 0208254813 COURSE Title Human Resource Development (HR)- (merge with evening stream COURSE Code SOMA 4743 Lecture Hall Name of Lecturer Dr. Freda Ocasey 0546708019', source: 'Business'),
  TimetableEntry(level: 400, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SOMA 4743', details: 'COURSE Title Product Mgt (MGT: MKTG) (merge with evening stream COURSE Code SOMA 4683 Lecture Hall Name of Lecturer Ms. Irene Owusu 0208254813 COURSE Title Human Resource Development (HR)- (merge with evening stream COURSE Code SOMA 4743 Lecture Hall Name of Lecturer Dr. Freda Ocasey 0546708019', source: 'Business'),
  TimetableEntry(level: 400, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOMA 4663', details: 'COURSE Title Advertising/Sales Promotion (MKTG, BBA (merge with evening stream COURSE Code SOMA 4663 Lecture Hall Name of Lecturer- Mr. Kwame Apau 0504031566 COURSE Title Knowledge Management (MGT:HR and ISS) COURSE Code SOMA 4713 Lecture Hall Name of Lecturer Mr. Joseph T. Tetteh-Quaynor 0549222223', source: 'Business'),
  TimetableEntry(level: 400, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOMA 4713', details: 'COURSE Title Advertising/Sales Promotion (MKTG, BBA (merge with evening stream COURSE Code SOMA 4663 Lecture Hall Name of Lecturer- Mr. Kwame Apau 0504031566 COURSE Title Knowledge Management (MGT:HR and ISS) COURSE Code SOMA 4713 Lecture Hall Name of Lecturer Mr. Joseph T. Tetteh-Quaynor 0549222223', source: 'Business'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SOMA 4513', details: 'COURSE Title Business & Corporate Strategy (MGT & BBA) SOMA 4513 Strategic Management (A/C COURSE Code SOMA 4773 Lecture Hall Name of Lecturer- Mr. Kwame Apau 0504031566', source: 'Business'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SOMA 4773', details: 'COURSE Title Business & Corporate Strategy (MGT & BBA) SOMA 4513 Strategic Management (A/C COURSE Code SOMA 4773 Lecture Hall Name of Lecturer- Mr. Kwame Apau 0504031566', source: 'Business'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SIEC 4583', details: 'COURSE Title Audit & Assurance I (A/C)- (merge with evening stream COURSE Code SOAC 3753 Lecture Hall Name of Lecturer Mr. Samuel Oko Asamoah 0546495247 COURSE Title Banking & Electronic Payment Systems (BBA)/ (merge with evening stream COURSE Code SIEC 4583 Lecture Hall Name of Lecturer Mr. Bismark Agbeworde Tel: 0549036567', source: 'Business'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SOAC 3753', details: 'COURSE Title Audit & Assurance I (A/C)- (merge with evening stream COURSE Code SOAC 3753 Lecture Hall Name of Lecturer Mr. Samuel Oko Asamoah 0546495247 COURSE Title Banking & Electronic Payment Systems (BBA)/ (merge with evening stream COURSE Code SIEC 4583 Lecture Hall Name of Lecturer Mr. Bismark Agbeworde Tel: 0549036567', source: 'Business'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '16:20–Scheduled', courseCode: 'SOMA 463', details: 'COURSE Title International Marketing -(MKTG) merge with evening stream COURSE Code SOMA 463 Lecture Hall Name of Lecturer Mr. Joseph T. Quanor 0549222223', source: 'Business'),
  TimetableEntry(level: 100, day: 'Monday', time: '08:30–11:15', courseCode: 'LAFR 1513', details: 'LAFR 1513 FRENCH LANGUAGE I - ALL MR DAVID TAWIAH (0242573588)', source: 'Computing'),
  TimetableEntry(level: 100, day: 'Monday', time: '12:25–15:25', courseCode: 'SIMS1572', details: 'SIMS1572 ALGEBRA – COMPUTER SCIENCE. and Eng. Laud Amenyo Fiase (0550225444)', source: 'Computing'),
  TimetableEntry(level: 100, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOGE 1573', details: 'SOGE 1573 STUDIES IN AFRICAN DEVELOPMENT - ALL Dr. Josiah Andor (0208905912)', source: 'Computing'),
  TimetableEntry(level: 100, day: 'Thursday', time: '12:25–15:25', courseCode: 'SICS1573', details: 'SICS1573 PRINCIPLES OF PROGRAMMING – COMPUTER SCIENCE, IT and Eng. Mr. Prince Joseph Sackey/Yaw Galo (0551423628)', source: 'Computing'),
  TimetableEntry(level: 100, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOED1533', details: 'SOED1533 INTRO. TO ACADEMIC WRITING I - ALL Mr. Bernard Sam Mobile: 0201122258', source: 'Computing'),
  TimetableEntry(level: 100, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SICS1533', details: 'SICS1533 FOUNDATIONS OF COMPUTER SCIENCE - COMPUTER SCIENCE and IT GIFTY OKYERE ANTI', source: 'Computing'),
  TimetableEntry(level: 100, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS 1593', details: 'SICS 1593 Introduction to Information Technology I – All Maame Baawa Osei-Akuamoah 0244758791', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Monday', time: '08:30–11:15', courseCode: 'SICS 2563', details: 'SICS 2563 Numerical Methods - Comp. Sci.. Mr. Prince Yirenkyi Saforo (0553617296) Venue:', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Monday', time: '12:25–15:25', courseCode: 'SOMA1533', details: '(SOMA1533) Introduction to Management - Info. Tech. Joining Mgt,A/C Mr. George Oppan Mobile:( 0244542373 ) Venue', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Thursday', time: '08:30–11:15', courseCode: 'SICS2553', details: '(SICS2553) Computer Organization - Comp. Sci. Mr. Stephen Obeng Kwarteng( 0246809200) Venue: (SIIS2513) Internet Programming I - Info. Tech. Mr. Michael Obiri (0549857056) Venue:', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Thursday', time: '08:30–11:15', courseCode: 'SIIS2513', details: '(SICS2553) Computer Organization - Comp. Sci. Mr. Stephen Obeng Kwarteng( 0246809200) Venue: (SIIS2513) Internet Programming I - Info. Tech. Mr. Michael Obiri (0549857056) Venue:', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Thursday', time: '12:25–15:25', courseCode: 'SIIS2573', details: '(SIIS2573) Application Programming With C# I – Info. Tech. Mr. Frank Opoku Aboagye (0244838689) Venue:', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SICS2573', details: 'SIIS 2553 Database System I/ SICS2573 Database Management Systems – All Computing + Computer Engineering(L300) Dr. Prince Joseph Sackey (0204226740)', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SIIS 2553', details: 'SIIS 2553 Database System I/ SICS2573 Database Management Systems – All Computing + Computer Engineering(L300) Dr. Prince Joseph Sackey (0204226740)', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SICS2533', details: '(SICS2533) Data Communications & Networks I/ SIEL3693 Data Communication & Computer Networks – All Computing, +Telecom Eng..+ Comp.Eng Kwadwo Opoku Attah (0203630210)', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SIEL3693', details: '(SICS2533) Data Communications & Networks I/ SIEL3693 Data Communication & Computer Networks – All Computing, +Telecom Eng..+ Comp.Eng Kwadwo Opoku Attah (0203630210)', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SICS2583', details: '(SICS2583) Operating Systems / SIEL 3883 Operating Systems Engineering – All Computing + Comp Eng (L300) Mr. Kwadwo Opoku Attah/ Yaw Galo (0551423628) Venue:', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SIEL 3883', details: '(SICS2583) Operating Systems / SIEL 3883 Operating Systems Engineering – All Computing + Comp Eng (L300) Mr. Kwadwo Opoku Attah/ Yaw Galo (0551423628) Venue:', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS2613', details: '(SICS2613) Programming With Java/ SIEL 3553 Java Programming – Comp. Sci.. +All Engineering - Dr. Prince Joseph Sackey (0204226740)', source: 'Computing'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SIEL 3553', details: '(SICS2613) Programming With Java/ SIEL 3553 Java Programming – Comp. Sci.. +All Engineering - Dr. Prince Joseph Sackey (0204226740)', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Friday', time: '08:30–11:15', courseCode: 'SICS 2513', details: '(SICS 2513) Mobile Application Development – All Computing Mohammed Umaru Yussif (050707277', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Monday', time: '12:25–15:25', courseCode: 'SICS3513', details: '(SICS3513) Human Computer Interactions – All Computing + Comp Eng. Mr. Michael Obiri (0549857056) Venue:', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Thursday', time: '08:30–11:15', courseCode: 'SICS 4683', details: 'SICS 4683 Visual Programming – Comp. Sci – Mr. Frank Opoku Aboagye (0244838689)', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Thursday', time: '12:25–15:25', courseCode: 'SOEC 3573', details: 'SOEC 3573 Research Methods – All Computing + All Eng. Dr. Daniel Michael Okwabi Adjin (0241236006) Venue:', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SIIS 4523', details: 'SIIS 4523 Knowledge Management - Info. Tech. (Joining MGT, HR) Mr. Joseph T. Tetteh-Quaynor Mobile: 0277425461 Venue::', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SICS 3793', details: '(SIEN3043) Geographical Information System I/ SICS 3793 Geographical Information Systems Fundamentals - All Computing Mr. Michael Obiri (0549857056) Venue:', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SIEN3043', details: '(SIEN3043) Geographical Information System I/ SICS 3793 Geographical Information Systems Fundamentals - All Computing Mr. Michael Obiri (0549857056) Venue:', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SICS 4583', details: '(SICS 4583) Multimedia Systems and Web Engineering – All Computing. + Comp Eng.(L400) Mr. Kwadwo Attah Opoku/Robert Aidoo (0553230881)', source: 'Computing'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS 3633', details: 'SICS 3633 Network Management and System Administration – All Computing Emmanuel Asare ( 0507339316) Venue:', source: 'Computing'),
  TimetableEntry(level: 400, day: 'Monday', time: '08:30–11:15', courseCode: 'SICS 4733', details: '(SICS 4733) Cloud Computing Fundamentals – All Computing. Kwadwo Attah Opoku (0203630210) Venue:', source: 'Computing'),
  TimetableEntry(level: 400, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOMA 3513', details: 'COURSE Title Entrepreneurship & Innovation (ALL) COURSE Code SOMA 3513 Lecture Hall Name of Lecturer Nana Yaw Boadi-Appiah 0246543736', source: 'Computing'),
  TimetableEntry(level: 400, day: 'Thursday', time: '12:25–15:25', courseCode: 'SICS4513', details: '(SICS4513) Artificial Intelligence & Expert Systems – All Computing + All Eng. Ms. Precious Obisike (059 429 4731) Venue:', source: 'Computing'),
  TimetableEntry(level: 400, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SICS4693', details: '(SICS4693) Computer Security – All Computing Mrs Maame Baawa Osei-Akuamoah (0244758791) Venue:', source: 'Computing'),
  TimetableEntry(level: 400, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SICS4673', details: '(SICS4673) Management Information Systems – All Computing Mrs Maame Baawa Osei-Akuamoah (0244758791) Venue:', source: 'Computing'),
  TimetableEntry(level: 100, day: 'Monday', time: '08:30–11:15', courseCode: 'LAFR 1513', details: 'LAFR 1513 FRENCH LANGUAGE I - ALL MR DAVID TAWIAH (0242573588)', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Monday', time: '12:25–15:25', courseCode: 'SIMS1572', details: 'SIMS1572 ALGEBRA – COMPUTER SCIENCE. and Eng. Laud Amenyo Fiase (0550225444)', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOGE 1573', details: 'SOGE 1573 STUDIES IN AFRICAN DEVELOPMENT - ALL Dr. Josiah Andor (0208905912)', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Thursday', time: '12:25–15:25', courseCode: 'SICS1573', details: 'SICS1573 PRINCIPLES OF PROGRAMMING – COMPUTER SCIENCE, IT and Eng. Mr. Prince Joseph Sackey (0204226740)', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SIEL1622', details: 'SIEL1622 Applied Physics – Eng. Laud Amenyo Fiase (0550225444)', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOED1533', details: 'SOED1533 INTRO. TO ACADEMIC WRITING I - ALL Mr. Bernard Sam Mobile: 0201122258', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SIEL 1773', details: 'SIEL 1773 Energy Conversion ………………………..', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS 1593', details: 'SICS 1593 Introduction to Information Technology I – All Maame Baawa Osei-Akuamoah 0244758791', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Monday', time: '08:30–11:15', courseCode: 'SICS 2563', details: 'SICS 2563 Numerical Methods – Eng. Mr. Prince Yirenkyi Saforo (0553617296) Venue:', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Monday', time: '16:20–Scheduled', courseCode: 'SIEL 2543', details: 'SIEL 2543 Instruments & Measurements I– Eng MR EMMAUEL MORNOH (0274310356) Venue:', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Thursday', time: '08:30–11:15', courseCode: 'SIEL 3513', details: 'SIEL 3513 Computer Architecture David Laud Amenyo Fiase (0550225444) Venue:', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Thursday', time: '12:25–15:25', courseCode: 'SIEL 2552', details: 'SIEL 2552 Electrical Machine I and Lab David Laud Amenyo Fiase (0550225444)', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SIEL 2523', details: 'SIEL 2523 Analogue Electronics Eng Dr. Eben Nornormey 020 300 1618 Venue:', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '16:20–Scheduled', courseCode: 'SIEL 2593', details: 'SIEL 2593 Signals and Systems - Eng Dr. Eben Nornormey 020 300 1618 Venue:', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SIMS 1643', details: 'SIMS 1643 Advanced Calculus David Laud Amenyo Fiase (0550225444)', source: 'Engineering'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS 1553', details: 'SICS 1553 Python Programming for Engineering+ Eng David Laud Amenyo Fiase /Emeka (0591737931).', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Monday', time: '08:30–11:15', courseCode: 'SIEL 3843', details: 'SIEL 3843 Analogue Circuits & Systems Design All Eng. Dr. Daniel Michael Okwabi Adjin (0202698175) Venue:', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Monday', time: '12:25–15:25', courseCode: 'SICS3513', details: '(SICS3513) Human Computer Interactions – All Computing+ Comp Eng Mr. Michael Obiri (0549857056) Venue: SIEL 4733 Communications Electronics – Tel Eng Dr. Daniel Michael Okwabi Adjin (0202698175)', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Monday', time: '12:25–15:25', courseCode: 'SIEL 4733', details: '(SICS3513) Human Computer Interactions – All Computing+ Comp Eng Mr. Michael Obiri (0549857056) Venue: SIEL 4733 Communications Electronics – Tel Eng Dr. Daniel Michael Okwabi Adjin (0202698175)', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Thursday', time: '12:25–15:25', courseCode: 'SOEC 3573', details: 'SOEC 3573 Research Methods – All Computing + All Eng. Dr. Daniel Michael Okwabi Adjin (0202698175) Venue:', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '08:30–11:15', courseCode: 'SICS2573', details: 'SICS2573 Database Management Systems – Comp. Eng. Mr. Prince Joseph Sackey (0204226740) Venue:', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SICS2533', details: 'SICS2533) Data Communications & Networks I/ SIEL3693 Data Communication & Computer Networks – All Eng. Kwadwo Opoku Attah (0203630210) Venue:', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SIEL3693', details: 'SICS2533) Data Communications & Networks I/ SIEL3693 Data Communication & Computer Networks – All Eng. Kwadwo Opoku Attah (0203630210) Venue:', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '16:20–Scheduled', courseCode: 'SIEL 3543', details: 'SIEL 3543 Optical Communication Systems - Tel Eng Dr. Daniel Michael Okwabi Adjin (0202698175)', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SIEL 3883', details: 'SIEL 3883 Operating Systems Engineering – Comp. Eng. ……………………. Venue:', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SIEL 4683', details: 'SIEL 4683 Digital Signal Processing & Filters - All Eng MR NELSON NATHANIEL (0203002424) Venue:', source: 'Engineering'),
  TimetableEntry(level: 300, day: 'Wednesday', time: '16:20–Scheduled', courseCode: 'SIEL 3573', details: 'SIEL 3573 Wireless Communication & RF design - Tel Eng MR NELSON NATHANIEL (0203002424)', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Monday', time: '12:25–15:25', courseCode: 'SIEL 3743', details: 'SIEL 4963 Mobile and Pervasive Computing – Compt. Eng. Kwadwo Atta Opoku (0203630210) Venue: SIEL 3743 Optoelectronics and Instruments Tel Eng MR EMMAUEL MORNOH (0274310356)', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Monday', time: '12:25–15:25', courseCode: 'SIEL 4963', details: 'SIEL 4963 Mobile and Pervasive Computing – Compt. Eng. Kwadwo Atta Opoku (0203630210) Venue: SIEL 3743 Optoelectronics and Instruments Tel Eng MR EMMAUEL MORNOH (0274310356)', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOMA 3513', details: 'COURSE Title SOMA 3513 Entrepreneurship & Innovation (ALL) Nana Yaw Boadi-Appiah 0246543736', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Thursday', time: '12:25–15:25', courseCode: 'SICS4513', details: '(SICS4513) Artificial Intelligence & Expert Systems – Comp. Eng +Tel Eng. Ms. Precious Obisike (059 429 4731) Venue:', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SIEL 3523', details: 'SIEL 3523 Advanced Computer Architecture- Compt. Eng Prince Joseph Sackey (0204226740) Venue:', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SICS 4583', details: 'SIEL 3723/ (SICS 4583) Multimedia Systems and Web Engineering – All Computing + Computer Eng. Mr. Kwadwo Attah Opoku/Robert Aidoo (0553230881)', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SIEL 3723', details: 'SIEL 3723/ (SICS 4583) Multimedia Systems and Web Engineering – All Computing + Computer Eng. Mr. Kwadwo Attah Opoku/Robert Aidoo (0553230881)', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SIEL4553', details: 'SIEL4553 Traffic Engineering - Tel Eng MR NELSON NATHANIEL (0203002424)', source: 'Engineering'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '16:20–Scheduled', courseCode: 'SIEL 4523', details: 'SIEL 4523 Aviation Communications and Instruments- Tel Eng Laud Amenyo Fiase (0550225444)', source: 'Engineering'),
  TimetableEntry(level: 100, day: 'Monday', time: '08:30–11:15', courseCode: 'LAFR 1513', details: 'COURSE Title French Language COURSE Code LAFR 1513 Name of Lecturer Dr. David Tawiah – 024 257 3588', source: 'Psychology'),
  TimetableEntry(level: 100, day: 'Thursday', time: '08:30–11:15', courseCode: 'SOGE 1573', details: 'COURSE Title Studies in African Development COURSE Code SOGE 1573 Name of Lecturer Dr. Josiah Andoh- 020 890 5912', source: 'Psychology'),
  TimetableEntry(level: 100, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOED 1533', details: 'COURSE Title Intro to Academic Writing COURSE Code SOED 1533 Lecture Hall Name of Lecturer Mr. Benard Sam – 020 112 2258', source: 'Psychology'),
  TimetableEntry(level: 100, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SICS 1593', details: 'COURSE Title Intro to Information Technology COURSE Code SICS 1593 Name of Lecturer Mrs Maame Baawa Osei-Akuamoah– 024 475 8791', source: 'Psychology'),
  TimetableEntry(level: 200, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOPS 2139', details: 'COURSE Title Theories of Leadership COURSE Code SOPS 2139 Name of Lecturer Dr. Vida Oppong – 024 487 1650.', source: 'Psychology'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SOPS 2139', details: 'COURSE Title Comparative Psychology COURSE Code SOPS 2139 Name of Lecturer Jessica Bajouse/Mrs. Dorothy Boateng – 050 647 2779 / – 050 647 2779 / 054 946 9716', source: 'Psychology'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SOPS 2131', details: 'COURSE Title Human Development I: Child and Adolescent COURSE Code SOPS 2131 Name of Lecturer Dr. Evelyn Owusu Roberts – 020 538 8916.', source: 'Psychology'),
  TimetableEntry(level: 200, day: 'Wednesday', time: '16:20–Scheduled', courseCode: 'SOPS 2133', details: 'COURSE Title Introduction to Biological Psychology COURSE Code SOPS 2133 Name of Lecturer Dr. Evelyn Owusu Roberts – 020 538 8916.', source: 'Psychology'),
  TimetableEntry(level: 300, day: 'Monday', time: '12:25–15:25', courseCode: 'SOPS 3133', details: 'COURSE Title Theories of Learning COURSE Code SOPS 3133 Name of Lecturer Dr. Vida Oppong – 024 487 1650.', source: 'Psychology'),
  TimetableEntry(level: 300, day: 'Monday', time: '16:20–Scheduled', courseCode: 'SOPS 3131', details: 'COURSE Title Introduction to Social Psychology COURSE Code SOPS 3131 Name of Lecturer Ms. Sylvia Hagan– 027 177 6384', source: 'Psychology'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '12:25–15:25', courseCode: 'SOPS 3137', details: 'COURSE Title Research Methods for Psychology COURSE Code SOPS 3137 Name of Lecturer Ms. Sylvia Hagan – 027 177 6384', source: 'Psychology'),
  TimetableEntry(level: 300, day: 'Tuesday', time: '16:20–Scheduled', courseCode: 'SOPS 3240', details: 'COURSE Title Psychological Tests, Measurements and Evaluation COURSE Code SOPS 3240 Name of Lecturer Dr Jephtar Adu-Mensah- 024 767 5260', source: 'Psychology'),
  TimetableEntry(level: 400, day: 'Monday', time: '08:30–11:15', courseCode: 'SOPS 4633', details: 'COURSE Title Industrial & Organizational Psychology COURSE Code SOPS 4633 Name of Lecturer Collins Courage Kofi – 024 770 5085', source: 'Psychology'),
  TimetableEntry(level: 400, day: 'Monday', time: '12:25–15:25', courseCode: 'SOPS 4137', details: 'COURSE Title Contemporary Issues in Psychology II COURSE Code SOPS 4137 Name of Lecturer Ms. Sylvia Hagan – 027 177 6384', source: 'Psychology'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '08:30–11:15', courseCode: 'SOPS 4506', details: 'COURSE Title Dissertation Progress Report to Supervisors. COURSE Code SOPS 4506 Name of Lecturer All Supervisors', source: 'Psychology'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '12:25–15:25', courseCode: 'SOPS 4133', details: 'COURSE Title Practicum COURSE Code SOPS 4133 Name of Lecturer Dr. Vida Oppong - 0244871650.', source: 'Psychology'),
  TimetableEntry(level: 400, day: 'Wednesday', time: '16:20–Scheduled', courseCode: 'SOPS 4139', details: 'COURSE Title Research Colloquium (Seminar) COURSE Code SOPS 4139 Name of Lecturer Ms. Sylvia Hagan– 027 177 6384', source: 'Psychology'),
];

List<TimetableEntry> timetableForSelection({
  required ProgramData program,
  required int level,
  required int semester,
}) {
  if (semester != 1) return const <TimetableEntry>[];
  final courseCodes = program.courses
      .where((course) => course.level == level && course.semester == semester)
      .map((course) => normalizeTimetableCourseCode(course.code))
      .toSet();
  final allowPublishedPsychologySchedule =
      program.name.contains('Psychology') && courseCodes.isEmpty;
  return firstSemester2026Timetable
      .where((entry) =>
          entry.level == level &&
          (allowPublishedPsychologySchedule ||
              courseCodes.contains(normalizeTimetableCourseCode(entry.courseCode))) &&
          _sourceMatchesProgram(entry.source, program.name))
      .toList(growable: false)
    ..sort((a, b) {
      const dayOrder = <String, int>{
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6,
      };
      final dayCompare = (dayOrder[a.day] ?? 99).compareTo(dayOrder[b.day] ?? 99);
      return dayCompare != 0 ? dayCompare : a.time.compareTo(b.time);
    });
}

bool _sourceMatchesProgram(String source, String programName) {
  return switch (source) {
    'Engineering' => programName.startsWith('BEng.'),
    'Computing' =>
      programName == 'BSc. Information Technology' ||
      programName == 'BSc. Computer Science' ||
      programName == 'BSc. Information Systems Sciences',
    'Psychology' => programName.contains('Psychology'),
    'Business' =>
      programName == 'BSc. Accounting with Information Systems' ||
      programName == 'Bachelor of Business Administration (E-Commerce)' ||
      programName == 'BSc. Management with Computing',
    _ => false,
  };
}
