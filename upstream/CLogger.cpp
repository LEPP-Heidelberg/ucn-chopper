#include "CLogger.h"
#include <stdarg.h>

CLogger::CLogger()
{
   m_pLogStdOut = stdout;
   m_pLogFile = NULL;
   
}

CLogger::~CLogger()
{
	
}

void CLogger::logSetFiles(FILE* pStdOut, FILE* pLogFile)
{
  m_pLogStdOut = pStdOut;
  m_pLogFile = pLogFile;
}


void CLogger::logWrite(const char *format, ...)
{
   
   va_list args;
   va_start(args, format);
    
   if (m_pLogStdOut != NULL)
      vfprintf(m_pLogStdOut, format, args);
   if (m_pLogFile != NULL)
      vfprintf(m_pLogFile, format, args);
   
   
   va_end(args);
}


