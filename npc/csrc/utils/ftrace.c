#include <utils.h>
#include <elf.h>
#include _HDR(TOP_NAME, __Dpi)

// 记录每一个函数名称以及起始地址和函数大小
typedef struct funcSymNode
{
    char *name;
    Elf_Addr addr;
    word_t size;
    struct funcSymNode *next;
} funcSymList;

// ftrace链表结点
typedef struct ftraceNode
{
    char *orginName;
    char *jFuncName;
    int callType; // 0 is call,1 is return;
    vaddr_t from_pc;
    vaddr_t to_pc;
    struct ftraceNode *next;
} ftraceList;

// 记录调用栈 call往链表中插入一个 return时删除一个 如果发现return的并不和链表尾相同 那么需要补充尾调用
typedef struct CallStackNode
{
    const char *func;
    struct CallStackNode *next;
} CallStack;

char *strtab = NULL; // 符号表字符串
// 带头结点的链表
funcSymList *sym_list = NULL;
ftraceList *ftrace_list = NULL;
ftraceList *tail = NULL; // 执行的是尾插法 为了方便输出

void init_ftrace(const char *elf_file)
{

    // 初始化ftrace
    ftrace_list = (ftraceList *)realloc(ftrace_list, sizeof(ftraceList));
    ftrace_list->next = NULL;
    tail = ftrace_list;

    // 初始化sym_list
    sym_list = (funcSymList *)realloc(sym_list, sizeof(funcSymList));
    sym_list->next = NULL;

    Assert(elf_file, "The elf_file is null");
    FILE *fp = fopen(elf_file, "r");
    Assert(fp, "Can not open '%s'", elf_file);

    // 读取ELF文件头
    Elf_Ehdr ehdr;
    Assert(fread(&ehdr, sizeof(Elf_Ehdr), 1, fp) == 1, "read the elf header failed");

    // 验证魔数
    bool sign = ehdr.e_ident[0] == 0x7f &&
                ehdr.e_ident[1] == 'E' &&
                ehdr.e_ident[2] == 'L' &&
                ehdr.e_ident[3] == 'F';
    Assert(sign, "The '%s' file not is a elf file", elf_file);

    // 查找字符串表
    fseek(fp, ehdr.e_shoff, SEEK_SET);
    Elf_Shdr shdr;

    for (int i = 0; i < ehdr.e_shnum; ++i)
    {
        Assert(fread(&shdr, sizeof(Elf_Shdr), 1, fp) == 1, "read the elf section header failed");

        //.strtab
        if (shdr.sh_type == SHT_STRTAB)
        {
            strtab = (char *)realloc(strtab, shdr.sh_size);
            fseek(fp, shdr.sh_offset, SEEK_SET);
            Assert(fread(strtab, shdr.sh_size, 1, fp) == 1, "read the .strtab failed");
            break;
        }
    }

    // 查找符号表
    fseek(fp, ehdr.e_shoff, SEEK_SET);
    for (int i = 0; i < ehdr.e_shnum; ++i)
    {
        Assert(fread(&shdr, sizeof(Elf_Shdr), 1, fp) == 1, "read the elf section header failed");

        //.symtab
        if (shdr.sh_type == SHT_SYMTAB)
        {
            fseek(fp, shdr.sh_offset, SEEK_SET);
            Elf_Sym sym;
            int num = shdr.sh_size / shdr.sh_entsize; // 存在多少个符号
            for (int i = 0; i < num; ++i)
            {
                Assert(fread(&sym, shdr.sh_entsize, 1, fp) == 1, "read the symbol table entry failed");
                if (ELF_ST_TYPE(sym.st_info) == STT_FUNC) // 函数符号
                {
                    struct funcSymNode *temp = (struct funcSymNode *)malloc(sizeof(struct funcSymNode));
                    temp->addr = sym.st_value;
                    temp->size = sym.st_size;
                    temp->name = strtab + sym.st_name; // 找到函数名称
                    temp->next = sym_list->next;
                    sym_list->next = temp;
                }
            }
            break;
        }
    }
    fclose(fp);
}

void insertFtraceNode(int callType, vaddr_t from_pc, vaddr_t to_pc)
{
    struct ftraceNode *node = (struct ftraceNode *)malloc(sizeof(struct ftraceNode));
    funcSymList *p = sym_list;

    node->callType = callType;
    node->from_pc = from_pc;
    node->to_pc = to_pc;

    while (p->next)
    {
        p = p->next;
        if (to_pc >= p->addr && to_pc < p->addr + p->size)
            node->jFuncName = p->name;
        if (from_pc >= p->addr && from_pc < p->addr + p->size)
            node->orginName = p->name;
    }
    node->next = NULL;
    tail->next = node;
    tail = node;
}

#define ALIGN_COL 52 // 设定统一对齐的列数
void printFtrace()
{
    ftraceList *p = ftrace_list;
    int num = 0;
    char buf[ALIGN_COL];

    CallStack *stack = (CallStack *)malloc(sizeof(CallStack)); // 记录的是每一次call的跳转地址
    stack->next = NULL;
    CallStack *node, *q;

    while (p->next)
    {
        p = p->next;
        // 打印前半部分到缓冲区，便于测长度
        int len = snprintf(buf, sizeof(buf), "[%s@" FMT_WORD "]", p->orginName, p->from_pc);

        // 输出前半部分
        printf("%s", buf);

        // 计算补齐空格
        int pad = ALIGN_COL - len;
        if (pad < 1)
            pad = 1; // 至少一个空格
        for (int i = 0; i < pad; ++i)
            putchar(' '); // 补空格直到对齐
        printf(":");
        for (int i = 0; i < num; ++i)
            printf(" ");
        if (p->callType) // return指令
        {
            printf("ret [%s]", p->jFuncName);
            node = stack->next;
            if (node->func == p->orginName) // 说明存在匹配 上一次的call JName就是这一次的return OriginName
            {
                if (node->next != NULL && node->next->func == p->jFuncName) // 再上一次的call JName是这一次return的JName 正常的一次call return: A(B() return)  call A call B return B return A
                {
                    printf("\n");
                    stack->next = node->next;
                    free(node);
                }
                else // 是尾调用的返回——尾调用插入的call 但是这次的ret是直接返回到好几次之前的 少了很多return 即 A(return B()) call A call B return A
                {
                    printf("(tail call---");
                    node = node->next;
                    while (node)
                    {
                        if (node->func == p->jFuncName)
                        {
                            printf("ret %s)\n", p->jFuncName);
                            break;
                        }
                        else
                            printf("ret %s,", node->func);
                        q = node;
                        node = node->next;
                        free(q);
                    }
                    stack->next = node;
                }
            }
            else // 这一次都没有call return的OriginName
            {
                printf("(tail call---");
                printf("call %s,", p->orginName);
                while (node)
                {
                    if (node->func == p->jFuncName)
                    {
                        printf("ret %s)\n", p->jFuncName);
                        break;
                    }
                    else
                        printf("ret %s,", node->func);
                    q = node;
                    node = node->next;
                    free(q);
                }
                stack->next = node;
            }
            num -= 2;
        }
        else // call指令
        {
            printf("call [%s@" FMT_WORD "]\n", p->jFuncName, p->to_pc);
            num += 2;
            if (stack->next) // stack非空
            {
                node = stack->next;
                q = (CallStack *)malloc(sizeof(CallStack));

                // 上一次的call jname和这一次call的 originName不一样 那么就说明中间其实是至少一次call originName的 这里只是粗略补充一次
                if (node->func != p->orginName)
                {
                    q->func = p->orginName;
                    q->next = stack->next;
                    stack->next = q;
                }
            }
            // 再补充call jName
            q = (CallStack *)malloc(sizeof(CallStack));
            q->func = p->jFuncName;
            q->next = stack->next;
            stack->next = q;
        }
    }
}

extern "C" void insertFtrace(int callType, const svBitVecVal *from_pc, const svBitVecVal *to_pc)
{
    insertFtraceNode(callType, *from_pc, *to_pc);
}