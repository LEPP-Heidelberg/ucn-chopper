#ifndef FILE_CLOGGER_H
#define FILE_CLOGGER_H



#include <stdio.h>
#include <stdint.h>

/*! \brief This allow to printout a message to two files at the same time
* The first one can be the stdout and the second one a file. The user can
* select if the output message has to be written to the two file or only
* one of then. The function logWrite use the same format as the printf.
* As default the logWrite function will be sent the text to the stdout if
* the function logSetFile has not been called. 
 ****************************************************************************/
class CLogger
{
   public:
      CLogger();
      ~CLogger();	
      void logSetFiles(FILE* pStdOut, FILE* pLogFile);
      void logWrite(const char *format, ...);
      
   
   private:     
    
      FILE* m_pLogFile;
      FILE* m_pLogStdOut;

};

#endif // FILE_CLOGGER_H
