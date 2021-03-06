'STATS GATHERING----------------------------------------------------------------------------------------------------
name_of_script = "NOTE - ACA Renewal"
start_time = timer

'LOADING ROUTINE FUNCTIONS----------------------------------------------------------------------------------------------------
Set run_another_script_fso = CreateObject("Scripting.FileSystemObject")
Set fso_command = run_another_script_fso.OpenTextFile("C:\MAXIS-BZ-Scripts-County-Beta\Script Files\FUNCTIONS FILE.vbs")
text_from_the_other_script = fso_command.ReadAll
fso_command.Close
Execute text_from_the_other_script



'DIALOGS----------------------------------------------------------------------------------------------------
BeginDialog Aca_renewal_dialog, 0, 0, 191, 155, "ACA Renewal"
  ButtonGroup ButtonPressed
    OkButton 140, 90, 50, 15
    CancelButton 140, 115, 50, 15
  EditBox 85, 5, 50, 15, case_number
  EditBox 85, 30, 15, 15, footer_month
  EditBox 115, 30, 15, 15, footer_year
  Text 105, 30, 10, 15, "/"
  Text 25, 30, 55, 15, "Review Month"
  Text 20, 70, 65, 15, "Caseworker Sign"
  EditBox 85, 70, 50, 15, worker_signature
  Text 20, 5, 60, 15, "Case Number"
  CheckBox 25, 50, 155, 15, "MMIS updated with MD exclusion.", MMIS_Check
  Text 15, 90, 115, 60, "WARNING:  This script will modify all waiting HC notices that are checked on the following screen.  Worker must uncheck any household members for which no results or ineligible results were approved."
EndDialog


'THE SCRIPT----------------------------------------------------------------------------------------------------

'Connects to BlueZone
EMConnect ""
EMFocus

'DATE CALCULATIONS----------------------------------------------------------------------------------------------------
next_month = dateadd("m", + 1, date)
footer_month = datepart("m", next_month)
If len(footer_month) = 1 then footer_month = "0" & footer_month
footer_year = datepart("yyyy", next_month)
footer_year = "" & footer_year - 2000
'Default the MMIS_Check to checked
MMIS_Check = 1

'Searches for a case number and footer month
call MAXIS_case_number_finder(case_number)
call find_variable("Month: ", MAXIS_footer_month, 2)
If row <> 0 then 
  footer_month = MAXIS_footer_month
  call find_variable("Month: " & footer_month & " ", MAXIS_footer_year, 2)
  If row <> 0 then footer_year = MAXIS_footer_year
End if


'Shows dialog, checks for MAXIS or WCOM status.
 Do
    Dialog ACA_renewal_dialog
 If ButtonPressed = 0 then stopscript
 If case_number = "" or IsNumeric(case_number) = False or len(case_number) > 8 then MsgBox "You need to type a valid case number."
 transmit 'sending refresh
 EMReadScreen MAXIS_check, 5, 1, 39
 If MAXIS_check <> "MAXIS" and MAXIS_check <> "AXIS " then script_end_procedure("You are not in MAXIS or you are locked out of your case.")
 Loop until MAXIS_check = "MAXIS" or MAXIS_check = "AXIS " and case_number <> "" and IsNumeric(case_number) = True and len(case_number) <= 8

'Creates household array
call navigate_to_screen("STAT", "MEMB")
call HH_member_custom_dialog(HH_member_array)

'Navigates to SPEC/WCOM, modifies the elig notices
call navigate_to_screen("SPEC", "WCOM")

 
  'This checks to make sure we've moved passed SELF.
  EMReadScreen SELF_check, 27, 2, 28
  If SELF_check = "Select Function Menu (SELF)" then script_end_procedure("Unable to get past SELF menu. Check for error messages and try again.")   
  'Updates to show HC only memos in chosen month
  EMWriteScreen footer_month, 3, 46
  EMWriteScreen footer_year, 3, 51
  EMWriteScreen "Y", 3, 74
  transmit
  for each HHmember in HH_member_array
   'Searches for notice for HHmember and exits if not found
   row = 7
   search_string = left(HHmember, 2) & "  01   Waiting"  
   EMSearch search_string, row, 61 
   if row = 0 then script_end_procedure("No notice for member " & HHmember & " found.  Please check for eligibility for this member and try again.")
 'Modifies the notice  
  EMWriteScreen "x", row, 13  
    Transmit
    EMReadScreen client_copy_check, 11, 1, 38
    If client_copy_check <> "Client Copy" then script_end_procedure("You are not able to go into update mode. Did you enter in inquiry by mistake? Please try again in production.")
    PF9
    EMWriteScreen "You will remain eligible for Medical Assistance because of", 3, 15 
    EMWriteScreen "new rules and guidelines.", 4, 15
    EMWriteScreen "(Authority: 42 C.F.R. 435.603(a)(3); Section 1902(e)(14)(A)", 5, 15                      
    PF4
    PF3
  next 
 
'Writes the case note
call navigate_to_screen("CASE", "NOTE")
PF9
EMSendkey "Approved new HC results.  The following HH Members remain eligible for an additional year of medical assistance due to change in rules and guidelines:" 
For each HH_member in HH_member_array
EMsendkey " " & HH_member
next
EMSendkey "<newline>"
If MMIS_check = 1 then EMsendkey "MMIS updated with MD exclusion."
EMSendkey "<newline>"
Call write_new_line_in_case_note(worker_signature)

script_end_procedure("")





