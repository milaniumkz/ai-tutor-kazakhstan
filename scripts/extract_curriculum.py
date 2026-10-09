"""Extract cited objective text; extraction does not assert applicability or review."""
import argparse
import hashlib
import json
import re
from datetime import datetime,timezone
from html.parser import HTMLParser
from pathlib import Path

class Blocks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.blocks=[];self.tag=None;self.anchor=None;self.text=[]
    def handle_starttag(self,tag,attrs):
        if tag in ('p','h3','h4'):
            self.finish()
            self.tag=tag;self.anchor=dict(attrs).get('id');self.text=[]
        elif tag=='br' and self.tag:self.text.append('\n')
        elif tag=='a' and self.tag and not self.anchor:self.anchor=dict(attrs).get('name')
    def handle_endtag(self,tag):
        if tag==self.tag:self.finish()
    def handle_data(self,data):
        if self.tag:self.text.append(data)
    def finish(self):
        if self.tag:
            self.blocks.append((self.tag,self.anchor,re.sub(r'[ \t\xa0]+',' ',''.join(self.text)).strip()))
            self.tag=None

def extract(path):
    raw=path.read_bytes();parser=Blocks();parser.feed(raw.decode('utf-8'));parser.finish()
    subjects=[];objectives={};subject=None;term=None
    for tag,anchor,text in parser.blocks:
        if tag=='h3' and text.startswith('Типовая учебная программа по учебному предмету'):
            subject=None;term=None
            if re.search(r'для [1-4](?:\s*[-–]\s*[1-4])? клас',text) and 'начального образования' in text:
                subject={'id':anchor or hashlib.sha256(text.encode()).hexdigest()[:12],'title':text,'source_anchor':anchor,'review_status':'pending'}
                subjects.append(subject)
        if not subject or tag!='p':continue
        if re.fullmatch(r'[1-4] четверть',text):term=int(text[0])
        matches=list(re.finditer(r'(?<!\d)([1-4]\.\d\.\d\.\d{1,2})(?!\d)',text))
        for index,match in enumerate(matches):
            code=match.group(1);description=text[match.end():matches[index+1].start() if index+1<len(matches) else len(text)].strip(' *;\n')
            if len(description)<12 or 'порядковый номер цели' in description:continue
            key=subject['id']+':'+code
            occurrence={'source_anchor':anchor,'term':term,'text':description}
            objective=objectives.setdefault(key,{'id':key,'subject_id':subject['id'],'code':code,'grade':int(code[0]),'review_status':'pending','occurrences':[]})
            if occurrence not in objective['occurrences']:objective['occurrences'].append(occurrence)
    return {'source':{'id':'kz-curriculum-399','url':'https://old.adilet.zan.kz/rus/docs/V2200029767',
        'sha256':hashlib.sha256(raw).hexdigest(),'retrieved_at':datetime.now(timezone.utc).isoformat(),
        'academic_year_applicability':'requires_methodologist_review','normative_review':'pending'},
        'subjects':subjects,'objectives':list(objectives.values()),'official_coverage':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('source',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
    result=extract(args.source);args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f"Extracted {len(result['subjects'])} programme sections and {len(result['objectives'])} objective records; review pending")
