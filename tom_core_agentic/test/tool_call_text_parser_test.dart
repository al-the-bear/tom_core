// Tests for the multi-format tool-call text parser.
//
// Many LLMs cannot (or will not) use a provider's native structured
// tool-call channel and instead emit the tool call as text in their own
// chat-template dialect. `parseToolCallsFromText` recognises the usual
// dialects and lowers them to one uniform `ParsedToolCall` shape, so a
// caller can recover a tool call regardless of which family the model
// belongs to. These tests pin each dialect plus the lenient argument
// parsing and the known-name filter.

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('parseToolCallsFromText — Gemma/Google sentinel + call:name{args}', () {
    test('parses the <|tool_call>call:web.search{...}<tool_call|> dialect', () {
      // The exact shape observed live from Gemma-on-oMLX: a sentinel-wrapped
      // functional call whose argument object uses *unquoted* keys.
      const text =
          '<|tool_call>call:web.search{query: "reliable sources for news online"}'
          '<tool_call|>';

      final calls = parseToolCallsFromText(text);

      expect(calls, hasLength(1));
      expect(calls.single.name, 'web.search');
      expect(calls.single.arguments,
          <String, Object?>{'query': 'reliable sources for news online'});
    });

    test('parses a bare call:file.search{pattern: "..."} without sentinels', () {
      const text = 'call:file.search{pattern: "answer_with_memory_v1.dart"}';

      final calls = parseToolCallsFromText(text);

      expect(calls, hasLength(1));
      expect(calls.single.name, 'file.search');
      expect(calls.single.arguments,
          <String, Object?>{'pattern': 'answer_with_memory_v1.dart'});
    });

    test('functional call with no args yields an empty argument map', () {
      final calls = parseToolCallsFromText('<|tool_call>call:memory.read{}<tool_call|>');
      expect(calls, hasLength(1));
      expect(calls.single.name, 'memory.read');
      expect(calls.single.arguments, isEmpty);
    });
  });

  group('parseToolCallsFromText — JSON object dialects', () {
    test('OpenAI-ish {"tool", "arguments"} object', () {
      final calls = parseToolCallsFromText(
          '{"tool": "memory.read", "arguments": {"q": "x"}}');
      expect(calls, hasLength(1));
      expect(calls.single.name, 'memory.read');
      expect(calls.single.arguments, <String, Object?>{'q': 'x'});
    });

    test('{"name", "parameters"} variant', () {
      final calls = parseToolCallsFromText(
          '{"name": "web.search", "parameters": {"query": "news"}}');
      expect(calls.single.name, 'web.search');
      expect(calls.single.arguments, <String, Object?>{'query': 'news'});
    });

    test('OpenAI nested {"function": {"name", "arguments": "<json-string>"}}', () {
      // The arguments here are a JSON *string* (as OpenAI tool_calls encode
      // them) and must be decoded a second time.
      final calls = parseToolCallsFromText(
          '{"function": {"name": "file.search", "arguments": "{\\"pattern\\": \\"x\\"}"}}');
      expect(calls.single.name, 'file.search');
      expect(calls.single.arguments, <String, Object?>{'pattern': 'x'});
    });

    test('markdown-fenced JSON tool call', () {
      final calls = parseToolCallsFromText(
          '```json\n{"tool": "memory.read", "arguments": {}}\n```');
      expect(calls.single.name, 'memory.read');
      expect(calls.single.arguments, isEmpty);
    });

    test('a JSON array of calls yields one ParsedToolCall each', () {
      final calls = parseToolCallsFromText(
          '[{"tool": "a", "arguments": {}}, {"tool": "b", "arguments": {"n": 1}}]');
      expect(calls.map((c) => c.name), <String>['a', 'b']);
      expect(calls[1].arguments, <String, Object?>{'n': 1});
    });
  });

  group('parseToolCallsFromText — Hermes/Qwen + Mistral dialects', () {
    test('<tool_call>{...}</tool_call> (Hermes/Qwen)', () {
      final calls = parseToolCallsFromText(
          'Sure.\n<tool_call>{"name": "web.search", "arguments": {"query": "q"}}</tool_call>');
      expect(calls.single.name, 'web.search');
      expect(calls.single.arguments, <String, Object?>{'query': 'q'});
    });

    test('[TOOL_CALLS] [ {...} ] (Mistral)', () {
      final calls = parseToolCallsFromText(
          '[TOOL_CALLS] [{"name": "memory.read", "arguments": {"id": "n1"}}]');
      expect(calls.single.name, 'memory.read');
      expect(calls.single.arguments, <String, Object?>{'id': 'n1'});
    });

    test('multiple <tool_call> blocks are all parsed in order', () {
      final calls = parseToolCallsFromText(
          '<tool_call>{"name":"a","arguments":{}}</tool_call>'
          '<tool_call>{"name":"b","arguments":{}}</tool_call>');
      expect(calls.map((c) => c.name), <String>['a', 'b']);
    });
  });

  group('parseToolCallsFromText — lenient argument values', () {
    test('single-quoted strings, numbers, booleans and null', () {
      final calls = parseToolCallsFromText(
          "call:t{a: 'hi', b: 3, c: 1.5, d: true, e: null}");
      expect(calls.single.arguments, <String, Object?>{
        'a': 'hi',
        'b': 3,
        'c': 1.5,
        'd': true,
        'e': null,
      });
    });

    test('nested objects and arrays', () {
      final calls = parseToolCallsFromText(
          'call:t{outer: {inner: "v"}, list: [1, 2, "x"]}');
      expect(calls.single.arguments, <String, Object?>{
        'outer': <String, Object?>{'inner': 'v'},
        'list': <Object?>[1, 2, 'x'],
      });
    });
  });

  group('parseToolCallsFromText — known-name filter & non-calls', () {
    test('plain prose yields no calls', () {
      expect(parseToolCallsFromText('The answer is 42.'), isEmpty);
    });

    test('a JSON object without a tool key yields no calls', () {
      // Valid JSON, but it is data, not a tool call.
      expect(parseToolCallsFromText('{"answer": 42}'), isEmpty);
    });

    test('knownToolNames filters out calls to unknown tools', () {
      const text = 'call:web.search{query: "x"} call:rm_rf{path: "/"}';
      final filtered =
          parseToolCallsFromText(text, knownToolNames: <String>{'web.search'});
      expect(filtered.map((c) => c.name), <String>['web.search']);
    });

    test('malformed input never throws — returns empty', () {
      expect(parseToolCallsFromText('<|tool_call>call:broken{a: '), isEmpty);
      expect(parseToolCallsFromText('{"tool": "x", "arguments": {bad'), isEmpty);
    });
  });

  group('looksLikeToolCallAttempt', () {
    test('true for an object-leading or marker-bearing text', () {
      expect(looksLikeToolCallAttempt('{"answer": 42}'), isTrue);
      expect(looksLikeToolCallAttempt('<tool_call>...'), isTrue);
      expect(looksLikeToolCallAttempt('call:web.search{}'), isTrue);
      expect(looksLikeToolCallAttempt('[TOOL_CALLS] [...]'), isTrue);
    });

    test('false for plain prose', () {
      expect(looksLikeToolCallAttempt('The answer is 42.'), isFalse);
    });
  });
}
