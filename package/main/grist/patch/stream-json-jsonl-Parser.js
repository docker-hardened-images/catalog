import parserImpl from './parser.js';

export function make(options) {
  return parserImpl.asStream(options);
}

export default parserImpl;
export const parser = parserImpl;
export const jsonlParser = parserImpl.jsonlParser;
export const asStream = parserImpl.asStream;
export const asWebStream = parserImpl.asWebStream;
