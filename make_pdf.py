# -*- coding: utf-8 -*-
"""
Pure-Python PDF generator (no external libraries).
Builds the ICT Strategy Guide (Darija) as a multi-page PDF.
"""

# ---- Helvetica character widths (per 1000 units) ----
_W = {
 ' ':278,'!':278,'"':355,'#':556,'$':556,'%':889,'&':667,"'":191,'(':333,')':333,
 '*':389,'+':584,',':278,'-':333,'.':278,'/':278,'0':556,'1':556,'2':556,'3':556,
 '4':556,'5':556,'6':556,'7':556,'8':556,'9':556,':':278,';':278,'<':584,'=':584,
 '>':584,'?':556,'@':1015,'A':667,'B':667,'C':722,'D':722,'E':667,'F':611,'G':778,
 'H':722,'I':278,'J':500,'K':667,'L':556,'M':833,'N':722,'O':778,'P':667,'Q':778,
 'R':722,'S':667,'T':611,'U':722,'V':667,'W':944,'X':667,'Y':667,'Z':611,'[':278,
 '\\':278,']':278,'^':469,'_':556,'`':333,'a':556,'b':556,'c':500,'d':556,'e':556,
 'f':278,'g':556,'h':556,'i':222,'j':222,'k':500,'l':222,'m':833,'n':556,'o':556,
 'p':556,'q':556,'r':333,'s':500,'t':278,'u':556,'v':500,'w':722,'x':500,'y':500,
 'z':500,'{':334,'|':260,'}':334,'~':584
}

def text_width(s, size, bold=False):
    total = 0
    for ch in s:
        total += _W.get(ch, 556)
    w = total / 1000.0 * size
    if bold:
        w *= 1.06
    return w

def wrap(text, size, maxw, bold=False):
    words = text.split(' ')
    lines = []
    cur = ''
    for word in words:
        trial = word if cur == '' else cur + ' ' + word
        if text_width(trial, size, bold) <= maxw:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            if text_width(word, size, bold) > maxw:
                part = ''
                for ch in word:
                    if text_width(part + ch, size, bold) <= maxw:
                        part += ch
                    else:
                        lines.append(part)
                        part = ch
                cur = part
            else:
                cur = word
    if cur:
        lines.append(cur)
    if not lines:
        lines = ['']
    return lines

# ---- Page geometry ----
PAGE_W, PAGE_H = 595.0, 842.0
ML, MR = 55.0, 50.0
MT, MB = 800.0, 55.0
USABLE_W = PAGE_W - ML - MR

# style: (font, size, leading, space_before, (r,g,b))
STYLES = {
 'title':    ('F2', 30, 36, 0,  (0.10, 0.13, 0.42)),
 'subtitle': ('F1', 13, 18, 8,  (0.30, 0.30, 0.30)),
 'h1':       ('F2', 19, 25, 20, (0.10, 0.22, 0.55)),
 'h2':       ('F2', 14, 19, 13, (0.13, 0.13, 0.13)),
 'h3':       ('F2', 12, 16, 9,  (0.20, 0.20, 0.20)),
 'body':     ('F1', 10.5, 14.5, 3, (0.0, 0.0, 0.0)),
 'bullet':   ('F1', 10.5, 14.5, 2, (0.0, 0.0, 0.0)),
 'note':     ('F2', 10.5, 14.5, 5, (0.55, 0.15, 0.10)),
}

def build_content(doc):
    content = []
    for raw in doc.split('\n'):
        line = raw.rstrip()
        if line == '':
            content.append(('space', ''))
        elif line == '[PB]':
            content.append(('pagebreak', ''))
        elif line == '---':
            content.append(('rule', ''))
        elif line.startswith('[TITLE] '):
            content.append(('title', line[8:]))
        elif line.startswith('[SUB] '):
            content.append(('subtitle', line[6:]))
        elif line.startswith('[NOTE] '):
            content.append(('note', line[7:]))
        elif line.startswith('### '):
            content.append(('h3', line[4:]))
        elif line.startswith('## '):
            content.append(('h2', line[3:]))
        elif line.startswith('# '):
            content.append(('h1', line[2:]))
        elif line.startswith('* '):
            content.append(('bullet', line[2:]))
        else:
            content.append(('body', line))
    return content

def layout(content):
    pages = [[]]
    y = [MT]

    def newpage():
        pages.append([])
        y[0] = MT

    for tag, text in content:
        if tag == 'pagebreak':
            newpage()
            continue
        if tag == 'space':
            y[0] -= 7
            continue
        if tag == 'rule':
            if y[0] - 10 < MB:
                newpage()
            pages[-1].append(('rule', ML, y[0] - 3, PAGE_W - MR))
            y[0] -= 11
            continue

        font, size, leading, space_before, color = STYLES[tag]
        y[0] -= space_before

        if tag == 'bullet':
            lines = wrap(text, size, USABLE_W - 16, bold=(font == 'F2'))
            for idx, ln in enumerate(lines):
                if y[0] < MB:
                    newpage()
                if idx == 0:
                    pages[-1].append(('text', ML, y[0], font, size, color, 'o'))
                pages[-1].append(('text', ML + 16, y[0], font, size, color, ln))
                y[0] -= leading
        else:
            lines = wrap(text, size, USABLE_W, bold=(font == 'F2'))
            for ln in lines:
                if y[0] < MB:
                    newpage()
                pages[-1].append(('text', ML, y[0], font, size, color, ln))
                y[0] -= leading
    return pages

def esc(s):
    return s.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')

def page_stream(ops):
    out = []
    for op in ops:
        if op[0] == 'text':
            _, x, yy, font, size, color, text = op
            r, g, b = color
            out.append('%.3f %.3f %.3f rg BT /%s %.2f Tf 1 0 0 1 %.2f %.2f Tm (%s) Tj ET'
                       % (r, g, b, font, size, x, yy, esc(text)))
        elif op[0] == 'rule':
            _, x1, yy, x2 = op
            out.append('0.65 0.65 0.65 RG 0.7 w %.2f %.2f m %.2f %.2f l S' % (x1, yy, x2, yy))
    return ('\n'.join(out)).encode('latin-1', 'replace')

def build_pdf(pages, path):
    objects = {}
    N = len(pages)
    # fixed objects
    objects[1] = b'<< /Type /Catalog /Pages 2 0 R >>'
    kids = ' '.join('%d 0 R' % (5 + 2 * i) for i in range(N))
    objects[2] = ('<< /Type /Pages /Kids [%s] /Count %d /MediaBox [0 0 %.0f %.0f] '
                  '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> >>'
                  % (kids, N, PAGE_W, PAGE_H)).encode('latin-1')
    objects[3] = b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'
    objects[4] = b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'

    for i in range(N):
        page_num = 5 + 2 * i
        cont_num = 6 + 2 * i
        objects[page_num] = (('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.0f %.0f] '
                              '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
                              '/Contents %d 0 R >>')
                             % (PAGE_W, PAGE_H, cont_num)).encode('latin-1')
        data = page_stream(pages[i])
        stream = b'<< /Length %d >>\nstream\n' % len(data) + data + b'\nendstream'
        objects[cont_num] = stream

    # write
    buf = bytearray()
    buf += b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n'
    offsets = {}
    max_obj = max(objects.keys())
    for num in range(1, max_obj + 1):
        if num not in objects:
            continue
        offsets[num] = len(buf)
        buf += ('%d 0 obj\n' % num).encode('latin-1')
        buf += objects[num]
        buf += b'\nendobj\n'

    xref_pos = len(buf)
    buf += ('xref\n0 %d\n' % (max_obj + 1)).encode('latin-1')
    buf += b'0000000000 65535 f \n'
    for num in range(1, max_obj + 1):
        if num in offsets:
            buf += ('%010d 00000 n \n' % offsets[num]).encode('latin-1')
        else:
            buf += b'0000000000 65535 f \n'
    buf += ('trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF'
            % (max_obj + 1, xref_pos)).encode('latin-1')

    with open(path, 'wb') as f:
        f.write(buf)
    return len(buf)

if __name__ == '__main__':
    import doc_content
    content = build_content(doc_content.DOC)
    pages = layout(content)
    size = build_pdf(pages, 'ICT_Strategy_Guide_Darija.pdf')
    print('PDF created: %d bytes, %d pages' % (size, len(pages)))
