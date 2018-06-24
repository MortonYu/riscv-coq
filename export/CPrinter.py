from LanguagePrinter import LanguagePrinter

type_mappings = {
    'BinNums.coq_Z': 'int'
}


def convert_type(t):
    global type_mappings
    res = type_mappings.get(t)
    if res:
        return res
    else:
        return t


class CPrinter(LanguagePrinter):
    def __init__(self, outfile):
        super(CPrinter, self).__init__(outfile)
        self.writeln('// This C file was autogenerated from Coq')
        self.end_decl()

    def end_decl(self):
        self.writeln('')

    def type_alias(self, name, rhsName):
        self.writeln('#define {} {}'.format(name, convert_type(rhsName)))
        self.end_decl()

    def enum(self, name, valueNames):
        self.writeln('typedef enum {' + ', '.join(valueNames) + '} ' + name + ';')
        self.end_decl()

    def variant(self, name, branches):
        '''
        name: str
        branches: list of (branchName, typesList) tuples
        '''
        self.enum(name + '_kind', ['K_' + b[0] for b in branches])
        self.writeln('typedef struct {')
        self.increaseIndent()
        self.writeln('{}_kind kind;'.format(name))
        # note: anonymous unions require "-std=c11"
        self.writeln('union {')
        self.increaseIndent()
        for branchName, argTypes in branches:
            self.writeln('struct {')
            self.increaseIndent()
            for i, t in enumerate(argTypes):
                self.writeln('{} f{};'.format(convert_type(t), i))
            self.decreaseIndent()
            self.writeln('} as_' + branchName + ';')
        self.decreaseIndent()
        self.writeln('};')
        self.decreaseIndent()
        self.writeln('} ' + name + ';')
        self.end_decl()

# in Coq pattern match, the pattern contains constructor, so we know the type to cast to
# fields of "case" class
