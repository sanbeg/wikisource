import sys
import popen2
import getopt
import optparse
import atexit
#wikipedia has the nasty habit of mixing status messages in stdout & stderr,
#so we need to hide stdout from it.
stdout = sys.stdout
sys.stdout = sys.stderr
import wikipedia
sys.stdout = stdout

atexit.register(wikipedia.stopme)

#process the global args (i.e. to specify -family) and the args we're
#interested in.
#(opts,args) = getopt.getopt(wikipedia.handleArgs(),'c:mtC')

#print args
#print opts

# minor = False
# comment = "Marked up for labeled section transclusion"
# do_put = True
# do_create = False
# interact = False

# for (k,v) in opts:
#     if k == '-c': comment = v
#     if k == '-C': do_create = True
#     elif k == '-m': minor = 1
#     elif k == '-i': interact = 1;
#     elif k == '-t': do_put = interact = False

opt_parse = optparse.OptionParser()
opt_parse.add_option('-c', '--comment', default="Marked up for labeled section transclusion")
opt_parse.add_option('-C', '--create', action="store_true")
opt_parse.add_option('-m', '--minor', action="store_true")
opt_parse.add_option('-i', '--interact', action="store_true")
opt_parse.add_option('-t', '--test', action="store_true")
opt_parse.add_option('--discard' action="store_true")

(opts,args) = opt_parse.parse_args(wikipedia.handleArgs())

if (len(args) != 2) :
    sys.stderr.write("Script requires 1 argument\n");
    sys.exit(1)

#(out_fh, in_fh) = popen2.popen2(args[0])
filt = popen2.Popen3(args[0]);

site = wikipedia.getSite()
page = wikipedia.Page(site, args[1])

#if there's an old doc, write it to the filter
if opts.create:
    if page.exists():
        sys.stderr.write("Page exists:" + args[1] + "\n");
        sys.exit(1)
else:
    try:
        if not opts.discard:
            filt.tochild.write(page.get().encode("utf8"))
    except wikipedia.NoPage:
        sys.stderr.write("Page not found:" + args[1] + "\n");
        sys.exit(1)
filt.tochild.close()
        
text = filt.fromchild.read().decode("utf");
filt.fromchild.close();
if filt.wait():
    sys.stderr.write("Filter exited with nonzero status.\n")
    sys.exit(1)

print(text)

if opts.interact:
    resp = wikipedia.input("Does this look OK (y/n)?");

    if (resp == "y"): do_put = 1
    else: do_put = 0

if not opts.test: page.put(text, comment=opts.comment, minorEdit=opts.minor);
