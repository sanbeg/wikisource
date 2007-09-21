#script to mirror help pages - Steve Sanbeg

"""
This script uses the pywikipedia framework to mirror help pages from the public
domain help project at http://www.mediawiki.org/ to a local installation.

The local wiki is specified using the normal pywikipedia command line options; the
source for the help files is hard-coded into the script.

"""
import sys
import atexit
import re
import optparse

import wikipedia
import upload

atexit.register(wikipedia.stopme)

#when writing to our own local wiki, use minimal throttling.
wikipedia.put_throttle.setDelay(1,True)
cat="[[Category:Imported help]]"

opt_parse = optparse.OptionParser()
opt_parse.add_option('-t', '--test', action="store_true", help="Test run, don't create anything")
opt_parse.add_option('--noimage', action="store_true", help="Don't copy images")

(opts,args) = opt_parse.parse_args(wikipedia.handleArgs())

#copy from mediawiki to our local wiki
src = wikipedia.getSite('www', 'mediawiki')  
src_url="http://%s/wiki"%src.hostname()
dst = wikipedia.getSite()

def write_page(src_page, template=False, text=None,
               cat_re = re.compile(re.escape(cat))):
    "Check whether this page should be written, and write it if allowed"
    
    name = src_page.title()
    dst_page = wikipedia.Page(dst,name)

    #should make this configurable; skip pages that are missing the category,
    #or are semi-protected.
    if dst_page.exists():
        #check category; any user could remove, or page could preexist
        if not cat_re.search(dst_page.get()):
            print "**Skipping page %s: not in category." % name
            return False
        #check page protection, allow admin to semi-protect
        if dst_page.editRestriction:
            print "**Skipping page %s: protected(%s)." % (name,dst_page.editRestriction)
            return False

    comment='Mirror from %s/%s'%(src_url,name)
    if not opts.test:
        if text == None: text = src_page.get()

        if template:
            #extra newlines in template will mess up table format
            text += "<noinclude>%s</noinclude>"%cat
        else:
            text += "\n%s\n"%cat
        
        if (not dst_page.exists()) or (text != dst_page.get()):
            dst_page.put(text,comment=comment)
    else:
        print "debug_write:", dst_page, "=>", comment 
        
#Default content for localized templates, to avoid importing things that are obviously
#irrelevant
local_override = {
    #generic header; link back to orgina, supress edit section links
    'PD Help Page': """:<div class=mw-warning>This page was automatically mirrored from %s/{{FULLPAGENAMEE}}</div>
__NOEDITSECTION__
"""%src_url,
    #used to link to meta; use extrnal link, so we don't depend on interwiki table
    'Meta':"""[http://meta.wikimedia.org/wiki/{{{1}}} {{{2|MetaWiki: {{{1}}}}}}] {{{3|}}}""",
    #generic footer, currently empty
    'Languages':'',
    }

    
count = 0 #for testing, track how many pages we've mirrored

#unfortunately, things look pretty bad if we don't follow links to find all
#of the necessary templates, so we need to get those, too.
template_cache=set() #cache seen templates, to avoid repeated downloads
#regex to match the templates we're interested in.
template_re = re.compile(r'[a-zA-Z0-9 _/]+[a-z]+[a-zA-Z0-9 _/]*$')

image_cache=set()

#We don't want sysop access on dst; we should be able to protect pages
#to save them from overwriting.
del wikipedia.config.sysopnames[dst.family.name][dst.lang]
#dst.forceLogin()

for k,v in local_override.iteritems():
    page = wikipedia.Page(src,"Template:%s"%k)
    template_cache.add(page)
    write_page(page,template=True,text=v)

write_page(wikipedia.Page(src,'Category:Help'),
           text="This category is used by help pages imported from %s"%src_url)

for page in src.allpages(namespace=12):
    print page.title()
    count += 1

    if "/" in page.title():
        print "Skip non-english page: %s" % page.title()
        continue

    #The FAQ just has too many issues, (interwiki links, etc)
    #I moved to Manual:FAQ, so this shouldn't be necessary.
    #if page.title() == 'Help:FAQ': continue
    
    #This whole loop is needed to follow the template links.  If the templates
    #were in NS:12, the outer loop would find them, and this would go away.
    #print " Templates:"
    for t in page.templates():
        #print "    {{%s}}" % t
        if template_re.match(t):
            #if t not in template_cache:
                #template_cache.add(t)
                tn = "Template:%s"%t
                tp = wikipedia.Page(src,tn)
                if tp not in template_cache:
                    #will get false positives from template help
                    if tp.exists(): write_page(tp,True)
                    template_cache.add(tp)
                #end template chasing

    #since this isn't entirely useful yet, don't copy everything, just
    #a few new ones to test 
    #if count<20: continue

    #Don't follow redirects, like [[mediawiki:en:Help:Configuration settings]]
    if page.isRedirectPage():
        print "  skip redirect"
        continue

    #look for images
    try:
        for img in page.imagelinks():
            if img not in image_cache:
                image_cache.add(img)
    except:
        print "Skip %s due to old pywikipedia bug; please upgrade your pywikiepdia"%page

    
    #Passed all the filters, so copy the page.
    write_page(page)
    #if count>5: break

print "Templates:"
for t in template_cache: print "  ", t

if not opts.noimage and not opts.test:
    for img in image_cache:
        if not isinstance(img,wikipedia.ImagePage):
            try:
                img=wikipedia.ImagePage(src,img.title())
            except:
                print "Skip invalid image: ", img
                continue
            print img, img.fileUrl()
            #don't replace images.
            if not wikipedia.Page(dst,img.title()).exists():
                #imgbot.transferImage(img);
                text=u'This image was mirrored from from %s/%s \n%s\n"'%(src_url,
                                                                         img.title(),
                                                                         cat)
                upload.UploadRobot(img.fileUrl(),targetSite=dst,
                                   keepFilename=True, verifyDescription=False,
                                   description=text).upload_image()
                #break

