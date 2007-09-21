import sys
import popen2
import getopt
import atexit
#wikipedia has the nasty habit of mixing status messages in stdout & stderr,
#so we need to hide stdout from it.
stdout = sys.stdout
sys.stdout = sys.stderr
import wikipedia
sys.stdout = stdout

atexit.register(wikipedia.stopme)

import string

#text of parent page
_parent_head="""
{{Header|
previous=%s
|next=%s
|title=[[%s]]
|section=Chapter %s
|author=| noauthor=
|notes=A comparison of various English translations and the sources they are derived from is available on a verse by verse basis.  A list of available translations of the entire book is found at [[%s]]
}}

<onlyinclude>
"""

_parent_foot = "</onlyinclude>\n\n{{Biblecontents}}\n"

_top_head="""
{{Header|
 previous=
|next=
|title=%s
|section=
|author=| noauthor=
|notes=
}}

==Translation Comparison==

"""

_top_foot =  "\n{{Biblecontents}}\n"


(opts,args) = getopt.getopt(wikipedia.handleArgs(),'c:mtCn:b:')


do_put = True
do_force = False
minor = False
comment = "Create page comparison of biblical translations"

for (k,v) in opts:
    if k == '-c': comment = v
    elif k == '-m': minor = 1
    elif k == '-t': do_put = False
    elif k == '-n': n_verses = int(v)
    elif k == '-f': do_force = True;
    
class MakePage:
    
    def __init__(self,name):
        self.name = name
        self.base = "Bible/%s" % name
        #self.parent = _parent_head % (self.base,self.base)
        self.top = _top_head % name
        self.do_put = do_put
        self.site = wikipedia.getSite('en', 'wikisource')
        
    def load(self,file):
        lines = open(file)
        self._list=[]
        for line in lines:
            list=line.split()
            if len(list)>0: self._list.append(list)
        lines.close()

    def mkverses(self):
        self._verses={}
        pc=0
        pv=0
        for i in range(0,len(self._list)):
            (c,v) = self._list[i]
            if (i+1 < len(self._list)):
                (nc,nv)=self._list[i+1]
            else:
                (nc,nv)=(0,0)
            
            #print 'chapt=%s,verse=%s,pc=%s,pv=%s,nc=%s,nv=%s'%(c,v,pc,pv,nc,nv)
            self.mkverse(c,v,pc,pv,nc,nv)
    
            if c != pc: self._verses[c]=[]
            self._verses[c].append(v)
            
            pc=c
            pv=v

        
    def mkverse(self,chapt,verse,pc,pv,nc,nv):
        base=self.base
        name=self.name
        
        page_name = "%s/%s/%s"%(base,chapt,str(verse))
        page = wikipedia.Page(self.site, page_name)
        
        if (not do_force) and self.do_put and page.exists():
            sys.stderr.write("Page exists:" + page_name + "\n");
        else:
            prev_tmp = "pc=%s|pv=%s"
            next_tmp = "nc=%s|nv=%s"
            if pc == 0:
                prev=prev_tmp%('','')
            else:
                prev=prev_tmp%(pc,pv)
            if nc == 0:
                next=next_tmp%('','')
            else:
                next=next_tmp%(nc,nv)
                               
            text = "{{%s|chapt=%s|verse=%s|%s|%s}}\n"%(
                base,chapt,verse,prev,next
                );
            if self.do_put: page.put(text, comment=comment, minorEdit=minor);
            else: print text
            
            return "*[[%s/%s/%s|%s %s:%s]]\n" % (base,chapt,verse,name,chapt,verse)

    def mkchapt(self):
        top_page = wikipedia.Page(self.site, self.base)
        top_text = self.top
        for i in range (0, len(self._verses)):
            #text = ""
            #text = self.parent
            c = str(i+1)
            if i>0:
                pc = "[[../%d|Chapter %d]]"%(i,i)
            else:
                pc = ""
            if i+1 < len(self._verses):
                nc = "[[../%d|Chapter %d]]"%(i+2,i+2)
            else:
                nc = ""
                
            text = _parent_head % (pc,nc,self.base,c,self.base)

            page_name = "%s/%s"%(self.base,c)
            page = wikipedia.Page(self.site, page_name)
            vs=self._verses[c] 
            top_text = top_text + "===Verses in Chapter %s===\n" % c + "{{/%s}}\n" % c
            for v in vs:
                text=text+ "* [[%s/%s/%s|%s %s:%s]]\n" % (self.base,c,v, self.name,c,v)
            text = text+_parent_foot
            if self.do_put: page.put(text, comment=comment, minorEdit=minor);
            else: print text

        top_text = top_text + _top_foot
        if self.do_put:
            if not top_page.exists():
                top_page.put(top_text, comment=comment, minorEdit=minor);
        else: print top_text


x = MakePage(args[0])
x.load(args[1])
x.mkverses()
x.mkchapt()
