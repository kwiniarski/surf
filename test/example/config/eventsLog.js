/**
 * @author Krzysztof Winiarski
 * @copyright (c) 2014 Krzysztof Winiarski
 * @license MIT
 */

'use strict';

module.exports = {
  transports: {
    Console: true,
    File: {
      stream: process.stdout
    }
  }
};
