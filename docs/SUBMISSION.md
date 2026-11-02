# Submission status

The four-program implementation passes the complete local and clean
instructor harnesses for 100/100. The implementation and verification
snapshot referenced by the report is
`1468b09ff2285baab9f8808c4e1c087150840809`.

The fork is [matthiola0/arch2026-progs](https://github.com/matthiola0/arch2026-progs),
with `main` as the default branch. Source changes, test tools, measurements,
and the English report are kept in this repository. The instructor's
contracts and grading framework are unchanged.

The [English report draft](https://hackmd.io/S1l3UJ8pfg) is in the personal
HackMD folder `Computer Arch`. Its initial named version is
`Review draft - four programs pass`. The saved content was checked against
`Report.md`. Review the note and verify instructor access before using its
link in the submission form; a personal draft is not a completed submission.

The current named version is `Prose revision - 2026-11-02`.

## Still required

The student will build and run CodeTrial on another computer.

- Review and understand the implementation and report.
- Build CodeTrial from source and practice its complete task-mode flow.
- Configure the student's own Gemini key and LiveKit Cloud project locally.
- Use the instructor's school-mail task link, PIN, and OAuth client details
  for the real attempt when supplied.
- Complete the English C interview independently and record the whole
  attempt from rules to learning review. No outside AI assistance is
  permitted during the attempt.
- Export the result and code before stopping the CodeTrial process.
- Follow the course's recording and submission instructions when announced.
- Update rv32emu and repeat complete grading before final submission,
  recording the new revision and any changed measurements.
- Submit the fork and final HackMD links through the announced form.

The CodeTrial prerequisite audit found Rust 1.99.1, Cargo 1.99.1, Clang 21,
and pkg-config in Ubuntu WSL. pkg-config does not currently find GLib's
development metadata. CodeTrial has not yet been built or configured in
this workspace, and no interview has been started. Build dependencies must
be rechecked against its current README and pinned Rust toolchain.

Never commit `codetrial.env.local`, API keys, LiveKit secrets, OAuth tokens,
or other account credentials. Enter credentials into the local setup page
or local configuration, not the report or chat.
