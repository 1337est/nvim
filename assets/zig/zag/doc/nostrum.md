# Original app idea

```
| Tasks                                                                                        |
| YYYYMMDD                                                                                     |
| -------------------------------------------------------------------------------------------- |
| CN - [ ] Yearly task name                                     YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Quarterly task name                                  YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Monthly task name                                    YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Weekly task name                                     YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Daily task name                                      YYYYMMDD : YYYYMMDD : yyyymmdd |
|                                                                                              |


| Journal Start - Streak X Days                | Journal Finish - Streak Y Days                |
| YYYYMMDD : yyyymmdd      YYYYMMDD : yyyymmdd | YYYYMMDD : yyyymmdd       YYYYMMDD : yyyymmdd |
| -------------------------------------------- | --------------------------------------------- |
| HHMM : hhmm                                  | HHMM : hhmm                                   |
| Write here to describe/write down the start  | Write here to describe/write about the end of |
| of your day. Blah blah blah blah. Streak X   | your day. Streak Y is the number of days I've |
| is the number of days I've written           | written continuously without break for Finish.|
| continuously without break for Start.        | HHMM : hhmm                                   |
| HHMM : hhmm                                  |                                               |
|                                              |                                               |


| Notes - Streak Z Days                                                                        |
| YYYYMMDD : yyyymmdd                                                     YYYYMMDD : yyyymmdd  |
| -------------------------------------------------------------------------------------------- |
| HHMM : hhmm                                                                                  |
| Write here notes you have throughout the day. Notes notes notes.                             |
| HHMM : hhmm                                                                                  |
|                                                                                              |
| YYYYMMDD : yyyymmdd                                                     YYYYMMDD : yyyymmdd  |
| -------------------------------------------------------------------------------------------- |
| HHMM : hhmm                                                                                  |
| This is a different note that spans 2 lines because it's a long detail about how your        |
| workout was. You normally don't workout anymore and it felt really really good!              |
| HHMM : hhmm                                                                                  |
|                                                                                              |
| YYYYMMDD : yyyymmdd                                                     YYYYMMDD : yyyymmdd  |
| -------------------------------------------------------------------------------------------- |
| HHMM : hhmm                                                                                  |
| As you can see, you can have many different Notes here.                                      |
| HHMM : hhmm                                                                                  |
|                                                                                              |
```
A terminal app that stores files of format `YYYYMMDD.md`. Example `20251016.md` would be October 16, 2025. Within this file contains tasks and notes for the day.

Every file should be linked together and know what the total count is for an item. Any "untracked" days should be automatically seen as "undone" and still contribute to the count.

Tasks are categorically broken up into 5 columns: Daily, Weekly, Monthly, Quarterly, and Yearly tasks. Tasks should be automatically pushed to the current `YYYYMMDD.md` file when they are due.

Notes are categorically broken up into 3 columns: Start, Finish, and Notes.

This is not a serious app and is mostly for learning purposes. The above is simply a scrappy model of what I'm trying to achieve at a basic level.

## Tasks

```
| Tasks                                                                                        |
| YYYYMMDD                                                                                     |
| -------------------------------------------------------------------------------------------- |
| CN - [ ] Yearly task name                                     YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Quarterly task name                                  YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Monthly task name                                    YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Weekly task name                                     YYYYMMDD : YYYYMMDD : yyyymmdd |
| CN - [ ] Daily task name                                      YYYYMMDD : YYYYMMDD : yyyymmdd |
```

Here's a basic template of how I see tasks currently. Yearly tasks are higher in precedence than Quarterly tasks, which are higher than Monthly tasks, etc. The N is the weight associated with when that task was due. The weight of tasks only shifts task precedence within a category.

- YYYYMMDD and yyyymmdd
    - Top/Header YYYYMMDD is the date for the current day.
    - Left YYYYMMDD in active tasks is the initial due date.
    - Middle YYYYMMDD in active tasks is the completed date.
    - Right yyyymmdd in active tasks is the next due date.
- C in CN
    - C stands for category and is the letter before the N and can be Y, Q, M, W, or D. These are symbols for Yearly, Quarterly, Monthly, Weekly, and Daily tasks.
- N in CN
    - w / d floored = N. Below is an example of Daily -> Yearly tasks and their associated weights represented by w / d, where w is the weight and d is the number of days. Each of these are incremented every day by w:
        - Daily. d = 1. (w / 1).
            - Read. w = 1. (1 / 1). Notification happens every day.
            - Exercise. w = 1. (1 / 1). Notification happens every day.
            - Lawn water. w = 0.33. (0.33 / 1). Notification happens every 3 days.
        - Weekly. d = 7. (w / 7).
            - Trash. w = 1. (1 / 7). Increments on Tuesdays and Fridays by w. Notification happens on Monday, Tuesday and Thursday, Friday. Notifications don't happen on any other days. If done Monday, Tuesday doesn't show. If done Thursday, Friday doesn't show.
            - Recycling. w = 1. (1 / 7). Increments on Tuesdays by w. Notification happens on Monday, Tuesday. Notifications don't happen on any other days. If done Monday, Tuesday doesn't show.
            - Laundry adults. w = 1. (1 / 7). Notification happens Friday, Saturday, Sunday. Notification persists until completed.
            - Laundry kids. w = 1. (1 / 7). Notification happens Friday, Saturday, Sunday. Notification persists until completed.
            - Laundry towels. w = 0.5. (1 / 7). Notification happens Friday, Saturday, Sunday. Notification persists until completed.
            - Lawn cut. w = 0.5. (1 / 7). Notification happens Saturday, Sunday. Notification persists until completed.
        - Monthly. d = 30. (w / 30).
            - Replace AC filters. w = 1. (1 / 30). Notification happens when above 1.0. Persists until completed.
            - Wash dog. w = 1. (1 / 30). Notification happens when above 1.0. Persists until completed.
            - Wash cars. w = 1. (1 / 30). Notification happens when above 1.0. Persists until completed.
            - Laundry bedding. w = 1. (1 / 30). Notification happens when above 1.0. Persists until completed.
        - Quarterly. d = 91. (w / 91)
            - Clean dusting. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean vacuum and sweep. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean mopping. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean bathrooms. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean kitchen. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean living room. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean garage. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean laundry room. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean parents rooms. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
            - Clean kids rooms. w = 1. (1 / 91). Notification happens when above 1.0. Persists until completed.
        - Yearly. d = 365. (w / 365)
            - Taxes. w = 1. (1 / 365). Notification happens February 1st of the new year with a due date of April 15. Persists until completed for that year. If undone after 1 year, will show both tax returns that need to be completed.
            - Car registration. w = 1. (1 / 365). Notification happens when above 1.0. Persists until completed.
            - Insurance Review and Update. w = 1. (1 / 365). Notification happens when above 1.0. Persists until completed.
            - Dental checkup. w = 1. (1 / 365). Notification happens when above 1.0. Persists until completed.
            - Health checkup. w = 1. (1 / 365). Notification happens when above 1.0. Persists until completed.
            - Vaccinations. w = 1. (1 / 365). Notification happens when above 1.0. Persists until completed.
            - Resume update. w = 1. (1 / 365). Notification happens when above 1.0. Persists until completed.
            - System and files backup. w = 1. (1 / 365). Notification happens when above 1.0. Persists until completed.
    - 0 <= N < 1 : means the task is not shown and is still iterating till its due date.
    - 1 <= N < 2 : means the task is due and should be done at your earliest convenience.
    - 2 <= N     : means the task is past it's initial due date, and has arrived at its second, third, fourth, etc. due date still without being done once. Make time for this task and complete it now! Once a task is completed, the weight is reset to 0, and is incremented at the regular rate again as determined by w / d. Tasks should therefore only be checked when they are fully completed, not in progress or "almost" done...

### Current development

The tasks are currently stored in a text file and each of the separate categories defined there should have their own parsers associated with said text file. This is how the database is created. I should consider using xml format instead of a plain .txt file, and I think I want the paradigm to be mostly whatever can be most easily created programmatically. This means that I want the parsing engine to be compatible with varying complexities depending on my needs for a certain category. These categories and their associated elements should simply be taken "as is", meaning there shouldn't be any (remove this, and add these things). The only time this may be necessary is when creating the markdown file. Currently the markdown file is simply being put directly into a .md file without any formatting, but this will be updated when I find the time to fix it.

## Journals & Notes

```
| Start - Streak X Days                        | Finish - Streak Y Days                        |
| YYYYMMDD : yyyymmdd      YYYYMMDD : yyyymmdd | YYYYMMDD : yyyymmdd       YYYYMMDD : yyyymmdd |
| -------------------------------------------- | --------------------------------------------- |
| HHMM : hhmm                                  | HHMM : hhmm                                   |
| Write here to describe/write down the start  | Write here to describe/write about the end of |
| of your day. Blah blah blah blah. Streak X   | your day. Streak Y is the number of days I've |
| is the number of days I've written           | written continuously without break for Finish.|
| continuously without break for Start.        | HHMM : hhmm                                   |
| HHMM : hhmm                                  |                                               |
|                                              |                                               |


| Notes - Streak Z Days                                                                        |
| YYYYMMDD : yyyymmdd                                                     YYYYMMDD : yyyymmdd  |
| -------------------------------------------------------------------------------------------- |
| HHMM : hhmm                                                                                  |
| Write here notes you have throughout the day. Notes notes notes.                             |
| HHMM : hhmm                                                                                  |
|                                                                                              |
| YYYYMMDD : yyyymmdd                                                     YYYYMMDD : yyyymmdd  |
| -------------------------------------------------------------------------------------------- |
| HHMM : hhmm                                                                                  |
| This is a different note that spans 2 lines because it's a long detail about how your        |
| workout was. You normally don't workout anymore and it felt really really good!              |
| HHMM : hhmm                                                                                  |
|                                                                                              |
| YYYYMMDD : yyyymmdd                                                     YYYYMMDD : yyyymmdd  |
| -------------------------------------------------------------------------------------------- |
| HHMM : hhmm                                                                                  |
| As you can see, you can have many different Notes here.                                      |
| HHMM : hhmm                                                                                  |
|                                                                                              |
```

Start is how you start your day. Finish is how you finish your day. I always want to finish what I start. Notes are any notes you have during the day. When you wake up and before you go to bed, you should be able to write a quick journaling of how you feel, dreams, accomplishments, or whatever you want really. The Streak X/Y/Z is how often you've continued the streak of journaling for either the Start, Finish, or Notes part of your day and are separate journaling streaks. There is no template and you're expected to just write down what you want. The YYYYMMDD : yyyymmdd to the left and right is the beginning and ending date of that written note. The HHMM : hhmm above and below every note is the beginning and ending time of that written note. The beginning date is on the left and the date documented is when you begin editing the note. The beginning time is on top and the time documented is when you begin editing the note. The ending date is on the right and the date documented is when the note was closed. The ending time is on bottom and the time documented is when the note was closed. The same rules pretty much apply to Notes as Start and Finish, other than: You can have many different Notes for a day. I might want to include a "tag" feature for my notes so I can easily search through all my notes for certain "tags". This would be done for Start, Finish, and Notes. Editing any note would allow me to change the contents, or the tag. Many tags can be associated to a note.

- YYYYMMDD : yyyymmdd
    - Left YYYYMMDD is the initial date of note creation.
    - Right YYYYMMDD is the initial date of close after creation.
    - Left yyyymmdd is the edit open date. Matches initial creation date originally, then changes if edited.
    - Right yyyymmdd is the edit close date. Matches initial close date originally, then changes if edited.
- HHMM : hhmm
    - Top HHMM is the initial time of note creation.
    - Bottom HHMM is the initial time of close after creation.
    - Top hhmm is the edit open time. Matches initial creation time originally, then changes if edited.
    - Bottom hhmm is the edit close time. Matches initial close time originally, then changes if edited.

# App name: nostrum (noun)

Below is the definition given from WordNet (r) 3.0 (2006) [wn]:

1. hypothetical remedy for all ills or diseases; once sought by the alchemists
2. patent medicine whose efficacy is questionable

I think this is funny because I've always bought journals/agenda's and never used them. I think agenda's should cure my procrastination and forgetfullness. Hypothetically if I used them, would my life be better? That is questionable. Time to find out if I'll finally use it if I make my own! I am the alchemist, in seek of my nostrum.
- Note: Nostrum sounds like nose. In seek of my nostrum makes me imagine crossing my eyes, looking at my nose, and saying "Found it!"

## Portability: C89, SQLite, Many Devices

This application will be for personal usage. Whether I'm at work on Windows/Mac, at home on my Linux machine, or on my mobile device, I need this application to be portable across all devices I may use.

### C89 & SQLite

I've chosen C89 because I want my application to be compatible across as many devices as possible. Most, if not all, compilers and operating systems implement the core of C, which means the app will compile and run across almost any hardware or software boundary with minimal modifications. I'm familiar with C++, but haven't really dived into C yet. The best way to learn a language is to learn the core of the language, and to make an application with it!

From my understanding, SQLite is an embeddable, self contained C library that masquerades as a database. This is lucrative for portability. Although I've used PostgreSQL briefly during a bootcamp, I haven't really written much SQL. This will also allow me to dip my toes into the proverbial soup of reality. Eww? Everybody uses/talks about SQLite. Time to find out what the big whoop is about.

## Accessibility: Offline, Online, New Device Download

The main purpose if to have a usable application anywhere I am, no matter the device and even with minimal connectivity. Therefore, I want this application to be available offline and online and be synchronizable across all devices I use the app on (with potentially some limitations). This means there needs to be an offline model before synchronization, and an online model for synchronization. Offline device storage will be through SQLite. If a device never connects to the internet, then I need to find a way to get the app on that device another way. If a computer is offline, but on a network with another computer where the application is installed, then there should be some secure method to transfer the application to the offline computer that is on the same network. Online storage and synchronization will be through TCP + TLS and PostgreSQL. TCP + TLS will also be used for onboarding new devices. The reason I'm going with TCP + TLS is also for learning. I know that HTTPS is basically this setup, but now it's time to see how it all works under the hood. I'm the surgeon and it's time to see how many times I can kill my patient before... it's ALLLIIIIIIVVEE!! Muahahahaha! But what if a computer isn't even on a network. What then? TODO: Update with what I'm doing and what I understand now.

## Database: SQLite and PostgreSQL

### Database: SQLite Amalgamation

### Database: Schema

## Network: TCP + TLS(OpenSSL & mbedTLS), LAN TCP sockets + mDNS Discovery for Peer Sync, Air-Gapped Export/Import (Encrypted Change Bundles)

I know the basics of what these do but haven't implemented them before (only UDP). Need to learn by doing. Maybe there's a different protocol that would suit my needs better? We'll see.

