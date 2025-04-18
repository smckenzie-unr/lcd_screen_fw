-- ***********************************************************************
-- Title    : Data Package
-- File     : data_package.vhd
-- Author   : Scott McKenzie
-- Date     : 03/29/2025
-- Version  : 1.0
-- Description:
--   This package provides type definitions for arrays of `std_logic_vector`
--   to facilitate the handling of one-dimensional and two-dimensional
--   arrays in VHDL designs.
--
-- Revision History:
--   Version 1.0: Initial release.
--
-- ***********************************************************************
library ieee;
use ieee.std_logic_1164.all;

-- ***********************************************************************
-- Package: std_logic_vector_arrays
-- Description: This package defines two types for working with arrays of
--              `std_logic_vector` in VHDL. These types are useful for
--              handling one-dimensional and two-dimensional arrays of
--              `std_logic_vector` signals.
--
-- Types:
--   1. slv_array:
--      - A one-dimensional array of `std_logic_vector`.
--      - The range of the array is defined dynamically using `natural range <>`.
--
--   2. slv_array2d:
--      - A two-dimensional array of `std_logic_vector`.
--      - Both dimensions of the array are defined dynamically using 
--        `natural range <>`.
--
-- Usage:
--   This package can be used to declare and manipulate arrays of 
--   `std_logic_vector` in VHDL designs, providing flexibility for 
--   parameterized and scalable designs.
-- ***********************************************************************

package std_logic_vector_arrays is
    type slv_array is array (natural range <>) of std_logic_vector;
    type slv_array2d is array (natural range <>, natural range <>) of std_logic_vector;
end std_logic_vector_arrays;