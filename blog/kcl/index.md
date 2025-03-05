# KCL's Computer Science Degree

I have been meaning to write an article about the quality of the KCL
computer science undergraduate course for some time. The goal of this 
article is twofold. (1) to advise prospective students about their 
choice of university for an undergraduate computer science course (2) to
present some potential directions for improvement of the KCL computer 
science course. I will also make some general comments about KCL as an
institution, but this is not the main goal.

Spoiler: I am not happy with the state of the course at all. I think it
needs a lot of improvement. I really want this article to be
_productive_ though, and not just me bashing KCL. If you believe that 
something is too harsh, or could be reworded, feel free to contact me
(my CV has my contact details) and I'll be sure to address it. Let's 
make KCL better!

## My Background 

I was a student of the Bachelor of Science in Computer Science at KCL,
for which I was awarded a First-class Honours degree. This is whence I
will get most of my thoughts about the course. I also have been a TA for
three different modules, totalling a few hundred hours of teaching. This
helps me understand a bit better some of the admin that goes on behind 
the scenes, and what we can expect of the students that make it to KCL.

## A First Look at the Course's Issues 

The first year is arguably the most important year of study. It gets
everyone to the same level, and sets the pace for the future years. In
the UK, especially for computer-science-adjacent roles, you are expected
to apply for internships before much of your second year has started, so
the first year is also responsible for preparing KCL's students to apply
to some of the most competitive internships schemes.

The first year of the course covers logic (first-order, second-order),
inductive proofs, Java programming, databases, data structures and an
introduction to computer architecture. This is a little sparse. It is
sparser still when you consider that these modules do not cover very
much depth on these topics. Sparser _still_ when you consider that most
of the content they claim to teach is entirely **optional**. This is
because the exam only tests a fraction of the content (which is all
available online due to the flipped classroom structure). You also only
need to achieve a 40% average on each of your modules, after *two*
attempts. Your first year average does not contribute at all to your
final degree outcome beyond pass/fail.

The issues with the first year are best understood through example.
Consider Java programming, called
[Programming Practice & Applications](https://www.kcl.ac.uk/abroad/module-options/module?id=dd960b11-d771-4eb6-9a95-9b8e2be60121).
It covers some simple object-oriented programming principles ('a `Car`
*is a* `Vehicle`), basic data types (a `String` is not an `int`) and
some control flow. The final couple of courseworks invite the student to
using Swing for some basic GUI programming.

The module's content is, of course, very important. These are concepts
that every computer scientist should know, whether they go into AI or
systems or PL research. The module is also lectured well, if a bit slow.
But, it is _vastly_ insufficient in depth. Students never learn many
concepts core to Java (type erasure, garbage collection, the JVM) not to
mention there is nothing about any other programming paradigm/style
(functional, systems, etc.).

Next problem: the module does not force students to actually _practise_
real programming. For one, the Java programming in PPA is too far from
'real' programming to be all that useful. Students are made to program
in the professor's own IDE (BlueJ). BlueJ is sort of halfway between
something like Scratch (block-based programming for kids) and proper
programming. It has some nice features like graphical class diagrams and
coloured blocks, which might help beginners, but to use it for the whole
year is, in my opinion, a big mistake. In my experience TAing, this
decision means that many students late into their second year are
unaware about what's actually going on when they write and run code.
Many students don't realise that it is not BlueJ that is executing their
Java code, but the JVM. They are surprised to learn that you could
compile Java code written in a plaintext editor. There are many such
knowledge gaps like this.

Furthermore, PPA has only ***four*** assessed courseworks, which means
only four assessed programming tasks in a whole year of a computer
science degree. The exam accounts for the plurality of the grade and is
a short multiple choice quiz on a laptop (most of KCL's final exams take
this form). On the upside, some of these issues are being worked on. The
course now lists a "class test", which I hope is some kind of assessed
programming task. The computer architecture module now also has a
coursework, so students are forced to do some programming there. Not all
bad! However, I would argue that even with these changes, students are
missing out on much needed practical programming experience. We need
more of it!

We have to ask ourselves if this is a reasonable request, though. Maybe
it's just too hard to get all that stuff marked? I took to the labs of
Imperial to interview some students about their first year programming
module, to see if maybe, this is just the best that can be done.  

The Imperial equivalent programming "omega module" is "Computing
Practical 1". Students are taught Haskell as their first language, the
idea here being that fewer people will know it and so the students are
on a more level playing field. There are _weekly_ marked assignments...
and... wait. That's already 5x the amount of feedback that is given to
the KCL students. Granted, these assignments are marked by third year
undergraduates who act as a "Personal Programming Tutor" (PPT). I have
been told that the quality varies. Some PPTs are naturally more
enthusiastic and provide better feedback, others only give crosses and
ticks. In my experience with PPA though, this is the same for the marked
courseworks we were given. I had ~100 words of feedback and a score.
Others had markers less generous with their comments. PPTs are also
responsible for meeting with their groups every week to discuss the
problem sheet, or go through some additional content if everyone did
well. Just like in PPA, CP1 has lab sessions every week that are TAed by
second and third year undergraduates. 

This is an excellent compromise. There's no need to make professors
answer students quibbles about programming (they're too busy doing
actual research) and there's not so much need to hire dedicated teaching
staff (because programming is not that hard). So just make the students
do it! The caveat is that you can't grade it, because standardising
grading is probably impossible with this system. But this system is
genius for another reason: the module content is too much for a student
to learn alone. But as we cycle a few years of this course, the students
who struggled through this module help the future generations learn from
their mistakes. Then this new generation of first years make stronger
PPTs for the future generations. You now have made an unmanageably
difficult module manageable without putting any burden on research
staff.

That's not all though, of course. Each language covered has two
assessments: a mini 'wake up' assessment worth 5% and a bigger
assessment worth 25% (or something like that). These are timed and in
exam conditions and _just programming_! **This is the way to do
programming assessments!**. You simply _cannot_ make students do
courseworks to gauge whether they can code in the era of GPT. It also
makes the students panic a little and learn more than they need to,
which means making them practise a lot more! Oh -- and first year counts
at Imperial. Not for much (7.5%), but any amount of weighting would have
been enough to make lazy old me try, for example. 

The second semester is Kotlin/Java with the same feedback structure.
They also cover some HTML and JavaScript and version control in there...
but apparently it's not much? The third 'semester' is C and assembler,
where they have to do a big group project building an ARM emulator in C.
This is especially nice, because (1) most people don't know ARM's
instruction set at this point (2) it's an actual real thing, not some
toy project. There is also an *assessed presentation* and *assessed
writeup*, for which you are given training.

In our evaluation here, we should think about whom a module is for.
There are a few camps of students that we might need to cater for.

1. People with extensive CS backgrounds
2. People with limited or no CS background, who are eager
3. Lazy people

For group 1, PPA provides nothing. I knew the entire course content
already, for example, and I had been programming for only a couple years
before university. The Imperial course provides huge benefit. As someone
in this camp, I would have learned Haskell (something I taught myself in
my third year), Kotlin and C, as well as ARM assembler. I would have
had some experience working with competent students in a group project,
improved my technical writing and presentation skills and maybe even
my work ethic.

For group 2, PPA teaches them the entire course content, exactly to the
degree it outlines on the module page (linked earlier). But after that,
they are left wondering what to do. The TAs are only as knowledgeable as
what PPA teaches (which is not much) and generally can't help beyond
that. Sometimes people get lucky with a fantastic TA who is so absurdly
smart and passionate and takes it upon himself to TA every module to an
excellent standard. But, this is just luck.

For group 3, PPA is a dream module! Prerecorded lectures from COVID
times are available online describing the _precise examinable subset_.
Simply GPT the courseworks, then get a 40 on the exam after cramming for
a night. Should we really be catering for this group? If we cater for
this group, we alienate the first two groups. Imperial shows us that
through clever choice of course content, we can design a course that
works for the first two groups, but not the third. KCL shows us that we
can design a course that works for the third group, but not the first
two. What we must do is take a strong stance against lazy students.
Ibelieve that most of the students at KCL are bright, and have it in
them to do well on a module similar to the Imperial's CP1 (maybe 70-80%
the difficulty). 

The first step is to change the assessment style to actual programming
assessments. This should immediately show that PPA is too easy as the
students find they cannot simply coast through the module with
generative AI. The next step is to restructure the content so it's new
to more people. BlueJ seems to be a mainstay and it is getting a Kotlin
extension, so use that. Put a _pure_ functional language, or Rust, or C
in first semester. Then, we can introduce the PPT system. Over a few 
years of running this module, taking one of these steps each year, we
can easily make it much better! 

## Course Content and Structure


DON'T READ THIS BIT YET IT'S JUST NOTES

taught by actually smart profs not ppl who do teaching

it is easy to forget that we can expect a lot more of the students

communicate with studetns more


A more general issue is 
that you really are only tested on these final exams, which means 
engagement throughout the year is terrible.

<!-- https://www.youtube.com/watch?v=m821Vz8N_bo&ab_channel=ACMSIGPLAN -->


ALl programming udner copmuting practical 1
first semester haskell
second semester kotlin (previously java) a bit of concurrency
third part C + assembly
4 or 5 week group project where you write assembler in C

PPT -- weekly task, feedback but no credit weekly meeting with tutor 
where you do questions on programming or discuss these tasks (student
run) first second term

taught, not flipped classroom 

interim test - 5% wake you up if you are retarded
january test - 25% final test 
same thing for java 
5% ethics test

C has no PPTs because you have a group project on C
tehre is a C test 12%

some optional lectures about HTML javascript and css

most exams are after easter 
