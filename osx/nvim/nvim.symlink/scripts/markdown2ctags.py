#!/usr/bin/env python

# Copyright (C) 2013-2018 John Szakmeister <john@szakmeister.net>
# All rights reserved.
#
# This software is licensed as described in the file LICENSE.txt, which
# you should have received as part of this distribution.

from __future__ import absolute_import
from __future__ import print_function

import codecs
import io
import locale
import pkg_resources
import sys
import re


def _version():
    '''Get version.'''
    try:
        return pkg_resources.get_distribution('markdown2ctags').version
    except pkg_resources.DistributionNotFound:
        return 'dev'


__version__ = _version()


class ScriptError(Exception):
    pass


def detect_encoding(filename):
    with open(filename, 'rb') as f:
        raw = f.read(4096)

    potential_bom = raw[:4]
    bom_encodings = [('utf-8-sig', codecs.BOM_UTF8),
                     ('utf-16', codecs.BOM_UTF16_LE),
                     ('utf-16', codecs.BOM_UTF16_BE),
                     ('utf-32', codecs.BOM_UTF32_LE),
                     ('utf-32', codecs.BOM_UTF32_BE)]
    for encoding, bom in bom_encodings:
        if potential_bom.startswith(bom):
            return encoding

    # No BOM found, let's try to detect encoding
    encoding = None
    try:
        import chardet

        result = chardet.detect(raw)

        # If we're not really confident about the encoding, then skip to
        # UTF-8 detection.
        if result['confidence'] >= 0.9:
            encoding = result['encoding']

        if encoding == 'ascii':
            encoding = 'utf-8'
    except ImportError:
        pass

    if encoding is None:
        try:
            raw.rsplit(b' ')[0].decode('utf-8')
            encoding = 'utf-8'
        except UnicodeDecodeError:
            pass

    return encoding or 'latin1'


def open_autoenc(filename, encoding=None):
    if encoding is None:
        encoding = detect_encoding(filename)
    return io.open(filename, encoding=encoding, newline='')


def ctagNameEscape(str):
    return re.sub('[\t\r\n]+', ' ', str)


def ctagSearchEscape(str):
    str = str.replace('\t', r'\t')
    str = str.replace('\r', r'\r')
    str = str.replace('\n', r'\n')
    str = str.replace('\\', r'\\')
    return str


class Tag(object):
    def __init__(self, tagName, tagFile, tagAddress):
        self.tagName = tagName
        self.tagFile = tagFile
        self.tagAddress = tagAddress
        self.fields = []

    def addField(self, type, value=None):
        if type == 'kind':
            type = None
        self.fields.append((type, value or ""))

    def _formatFields(self):
        formattedFields = []
        for name, value in self.fields:
            if name:
                s = '%s:%s' % (name, value or "")
            else:
                s = str(value)
            formattedFields.append(s)
        return '\t'.join(formattedFields)

    def render(self):
        return '%s\t%s\t%s;"\t%s' % (
            self.tagName, self.tagFile, self.tagAddress, self._formatFields())

    def __repr__(self):
        return "<Tag name:%s file:%s: addr:%s %s>" % (
            self.tagName, self.tagFile, self.tagAddress,
            self._formatFields().replace('\t', ' '))

    def _tuple(self):
        return (self.tagName, self.tagFile, self.tagAddress,
                self._formatFields())

    def __eq__(self, other):
        return self._tuple() == other._tuple()

    def __ne__(self, other):
        return self._tuple() != other._tuple()

    def __lt__(self, other):
        return self._tuple() < other._tuple()

    def __le__(self, other):
        return self._tuple() <= other._tuple()

    def __gt__(self, other):
        return self._tuple() > other._tuple()

    def __ge__(self, other):
        return self._tuple() >= other._tuple()

    @staticmethod
    def section(section, sro):
        tagName = ctagNameEscape(section.name)
        tagAddress = '/^%s$/' % ctagSearchEscape(section.line)
        t = Tag(tagName, section.filename, tagAddress)
        t.addField('kind', 's')
        t.addField('line', section.lineNumber)

        parents = []
        p = section.parent
        while p is not None:
            parents.append(ctagNameEscape(p.name))
            p = p.parent
        parents.reverse()

        if parents:
            t.addField('section', sro.join(parents))

        return t


class Section(object):
    def __init__(self, level, name, line, lineNumber, filename, parent=None):
        self.level = level
        self.name = name
        self.line = line
        self.lineNumber = lineNumber
        self.filename = filename
        self.parent = parent

    def __repr__(self):
        return '<Section %s %d %d>' % (self.name, self.level, self.lineNumber)


def popSections(sections, level):
    while sections:
        s = sections.pop()
        if s and s.level < level:
            sections.append(s)
            return


atxHeadingRe = re.compile(r'^(#+)\s+(.*?)(?:\s+#+)?\s*$')
settextHeadingRe = re.compile(r'^[-=]+$')
settextSubjectRe = re.compile(r'^[^\s]+.*$')


def findSections(filename, lines):
    sections = []
    inCodeBlock = False
    beyondFrontMatter = False
    inFrontMatter = False

    previousSections = []

    for i, line in enumerate(lines):
        # Some markdown-based tools allow for "front matter" at the beginning
        # of the file.  The data is demarcated by a leading and trailing triple
        # hyphen (---) on its own line.  The tools I've looked at, like Jekyll,
        # expect this to start on the first line.  So here's an attempt to skip
        # over the front matter and only tag the remaining part of the file.
        if not beyondFrontMatter:
            if line == "":
                continue
            elif line == '---':
                inFrontMatter = not inFrontMatter
                continue

            if not inFrontMatter and line:
                beyondFrontMatter = True


        # Skip GitHub Markdown style code blocks.
        if line.startswith("```"):
            inCodeBlock = not inCodeBlock
            continue

        if inCodeBlock:
            continue

        m = atxHeadingRe.match(line)
        if m:
            level = len(m.group(1))
            name = m.group(2)

            popSections(previousSections, level)
            if previousSections:
                parent = previousSections[-1]
            else:
                parent = None
            lineNumber = i + 1

            s = Section(level, name, line, lineNumber, filename, parent)
            previousSections.append(s)
            sections.append(s)
        else:
            m = settextHeadingRe.match(line)
            if i and m:
                if not settextSubjectRe.match(lines[i - 1]):
                    continue

                name = lines[i-1].strip()

                if line[0] == '=':
                    level = 1
                else:
                    level = 2

                popSections(previousSections, level)
                if previousSections:
                    parent = previousSections[-1]
                else:
                    parent = None
                lineNumber = i

                s = Section(level, name, lines[i-1], lineNumber,
                            filename, parent)
                previousSections.append(s)
                sections.append(s)

    return sections


def sectionsToTags(sections, sro):
    tags = []

    for section in sections:
        tags.append(Tag.section(section, sro))

    return tags


def genTagsFile(output, tags, sort):
    if sort == "yes":
        tags = sorted(tags)
        sortedLine = b'!_TAG_FILE_SORTED\t1\t//\n'
    elif sort == "foldcase":
        tags = sorted(tags, key=lambda x: str(x).lower())
        sortedLine = b'!_TAG_FILE_SORTED\t2\t//\n'
    else:
        sortedLine = b'!_TAG_FILE_SORTED\t0\t//\n'

    output.write(b'!_TAG_FILE_ENCODING\tutf-8\t//\n')
    output.write(b'!_TAG_FILE_FORMAT\t2\t//\n')
    output.write(sortedLine)

    for t in tags:
        output.write(t.render().encode('utf-8'))
        output.write('\n'.encode('utf-8'))


def main():
    from optparse import OptionParser

    parser = OptionParser(usage="usage: %prog [options] file(s)",
                          version=__version__)
    parser.add_option(
        "-f", "--file", metavar="FILE", dest="tagfile",
        default="tags",
        help='Write tags into FILE (default: "tags").  Use "-" to write '
             'tags to stdout.')
    parser.add_option(
        "", "--encoding", metavar="ENCODING", dest="encoding",
        default=None,
        help='Skips auto detection and uses the specified encoding for the '
             'input files.  Encoding name should be one that Python would '
             'recognize.')
    parser.add_option(
        "", "--sort", metavar="[yes|foldcase|no]", dest="sort",
        choices=["yes", "no", "foldcase"],
        default="yes",
        help='Produce sorted output.  Acceptable values are "yes", '
             '"no", and "foldcase".  Default is "yes".')
    parser.add_option(
        "", "--sro", metavar="SEPARATOR", dest="sro",
        default="|", action="store",
        help=u'Use the specified string to scope nested headings.  The '
              'default is pipe symbol ("|"), but that can be an issue if your '
              'headings contain the pipe symbol.  It might be more useful to '
              'use a such as the UTF-8 chevron ("\u00bb").')

    options, args = parser.parse_args()

    if sys.version_info[0] == 2:
        encoding = sys.stdin.encoding or locale.getpreferredencoding() or 'utf-8'
        options.sro = options.sro.decode(encoding)

    if options.tagfile == '-':
        if sys.version_info[0] == 2:
            output = sys.stdout
        else:
            output = sys.stdout.buffer
    else:
        output = open(options.tagfile, 'wb')

    for filename in args:
        if sys.version_info[0] == 2:
            filename = filename.decode(sys.getfilesystemencoding())

        with open_autoenc(filename, encoding=options.encoding) as f:
            lines = f.read().splitlines()

        sections = findSections(filename, lines)

        genTagsFile(output,
                    sectionsToTags(sections, options.sro),
                    sort=options.sort)

    output.flush()
    output.close()


def cli_main():
    try:
        main()
    except IOError as e:
        import errno
        if e.errno == errno.EPIPE:
            # Exit saying we got SIGPIPE.
            sys.exit(141)
        raise
    except ScriptError as e:
        print("ERROR: %s" % str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    cli_main()
