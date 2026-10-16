# dlGrep - dnGrep revisited

A powerful visual Grep program for Windows

---
Program summary, from original [dnGrep](https://dngrep.github.io/) utility  
dnGrep allows you to search across files with easy-to-read results. Search through text files, Word and Excel documents, PDFs, and archives using text, regular expression, XPath, and phonetic queries. dnGrep includes search-and-replace, whole-file preview, right-click search in File Explorer, and much more.

---
`dlGrep` is forked from `dnGrep`, but adds a couple of specific features that I wanted,
and original author did not want to implement.

New features in `dlGrep`:  
- A scrollable "Replace Log" window, which shows all "Replace" and "Skip" operations
that were performed during a "Replace" operation.  See the image below for an example 
of this log window.  
- Option to save the "Replace Log" with colors as HTML file
- "Replace Text" dialog has been reduced in size, to hide some operations that I don't ever use.

Here is its [Home page](https://github.com/DerellLicht/dlGrep)  
Download the [installer](https://github.com/DerellLicht/dnGrep/releases/latest) here  
See [Changelog](https://github.com/DerellLicht/dlGrep/blob/master/CHANGELOG.md) for the full revision history  
`dnGrep` uses the GPL 3.0 license; view the file 
[here](https://github.com/DerellLicht/dlGrep/blob/master/license.txt) 

![Example of Replace Log pane](https://github.com/DerellLicht/dlGrep/blob/master/docs/dlGrep.replace.log.jpg?raw=true)

---
Notes on this revisited version of `dlGrep` ...  
I did the design specification, testing, and guidance on the revisions in this fork of the program.

However: [Claude AI](https://claude.ai/new) did *all* of the coding and interpretation of the existing code.
Claude is truly amazing; he implements complex designs in seconds, and they generally 
do exactly what was requested... but debugging and analysis still require a human.
The two of us together, can do almost *anything* !!

---
This program is derived from, and expands upon, 
[dnGrep](https://dngrep.github.io/),
created by 
[@doug24](href="https://github.com/doug24")  
