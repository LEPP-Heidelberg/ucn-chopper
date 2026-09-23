-- $Id: svn_extract.vhd 1 2016-03-15 14:35:42Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

-- Define these two constants in your code:
-- constant svn_rev  : string := "$Rev: 1 $";
-- constant svn_date : string := "$Date: 2016-03-15 15:35:42 +0100 (Tue, 15 Mar 2016) $";
-- and call so:
-- get_rev(svn_rev)
-- get_day(svn_date)
-- get_month(svn_date)
-- get_year(svn_date)

package svn_extract is

function get_ver(revision: string) return Integer;
function get_year(datestr : string) return Integer;
function get_month(datestr : string) return Integer;
function get_day(datestr : string) return Integer;

end svn_extract;

package body svn_extract is

function char2dig(char : character) return Integer is
variable res : Integer;
begin
    res := -1;
    case char is
    when '0' => res := 0;
    when '1' => res := 1;
    when '2' => res := 2;
    when '3' => res := 3;
    when '4' => res := 4;
    when '5' => res := 5;
    when '6' => res := 6;
    when '7' => res := 7;
    when '8' => res := 8;
    when '9' => res := 9;
    when others => NULL;
    end case;
    return res;
end;

function get_ver(revision : string) return Integer is
variable beg_found : Boolean;
variable rev : Integer;
begin
    beg_found := false;
    rev := 0;
L1: for i in 1 to revision'length loop
        if revision(i)=' ' then
            if beg_found then
                exit L1;
            else
                beg_found := true;
            end if;
        else
            if beg_found then
                rev := 10*rev + char2dig(revision(i));
            end if;
        end if;
    end loop;
    return rev;
end;

function get_year(datestr : string) return Integer is
variable beg_found : Boolean;
variable year : Integer;
begin
    beg_found := false;
    year := 0;
L1: for i in 1 to datestr'length loop
        if datestr(i)='-' then
            exit L1;
        end if;
        if datestr(i)=' ' then
            beg_found := true;
        else
            if beg_found then
                year := 10*year + char2dig(datestr(i));
            end if;
        end if;
    end loop;
    return year;
end;

function get_month(datestr : string) return Integer is
variable beg_found : Boolean;
variable month  : Integer;
variable delidx : Integer;
begin
    beg_found := false;
    month := 0;
    delidx := 0;
L1: for i in 1 to datestr'length loop
        if datestr(i)='-' and delidx=1 then
            exit L1;
        end if;
        if datestr(i)='-' and delidx=0 then
            beg_found := true;
            delidx := 1;
        else
            if beg_found then
                month := 10*month + char2dig(datestr(i));
            end if;
        end if;
    end loop;
    return month;
end;

function get_day(datestr : string) return Integer is
variable beg_found : Boolean;
variable day    : Integer;
variable delidx : Integer;
begin
    beg_found := false;
    day    := 0;
    delidx := 0;
L1: for i in 1 to datestr'length loop
        if datestr(i)=' ' and delidx=2 then
            exit L1;
        end if;
        if datestr(i)='-' and delidx=1 then
            beg_found := true;
            delidx:=2;
        else
            if beg_found then
                day := 10*day + char2dig(datestr(i));
            end if;
            if datestr(i)='-' and delidx=0 then
                delidx := 1;
            end if;
        end if;
    end loop;
    return day;
end;

end svn_extract;
