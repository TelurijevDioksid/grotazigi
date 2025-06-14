// From:
//     https://github.com/leroycep/zig-jwt
//

const std = @import("std");
const testing = std.testing;
const ValueTree = std.json.ValueTree;
const Value = std.json.Value;
const base64url = std.base64.url_safe_no_pad;

const Algorithm = enum {
    const Self = @This();

    HS256,
    HS384,
    HS512,

    pub fn jsonStringify(value: Self, options: std.json.StringifyOptions, writer: anytype) @TypeOf(writer).Error!void {
        try std.json.stringify(std.meta.tagName(value), options, writer);
    }

    pub fn CryptoFn(comptime self: Self) type {
        return switch (self) {
            .HS256 => std.crypto.auth.hmac.sha2.HmacSha256,
            .HS384 => std.crypto.auth.hmac.sha2.HmacSha384,
            .HS512 => std.crypto.auth.hmac.sha2.HmacSha512,
        };
    }
};

const JWTType = enum {
    JWS,
    JWE,
};

pub const SignatureOptions = struct {
    key: []const u8,
    kid: ?[]const u8 = null,
};

pub fn extractClaims(comptime P: type, allocator: std.mem.Allocator, token: []const u8) !std.json.Parsed(P) {
    const first_dot_idx = std.mem.indexOfScalar(u8, token, '.') orelse return error.InvalidFormat;
    const second_dot_idx = std.mem.lastIndexOfScalar(u8, token, '.') orelse return error.InvalidFormat;
    const middle = token[first_dot_idx + 1 .. second_dot_idx];
    const decoded = try allocator.alloc(u8, try base64url.Decoder.calcSizeForSlice(middle));
    try base64url.Decoder.decode(decoded, middle);
    return std.json.parseFromSlice(P, allocator, decoded, .{});
}

pub fn encode(allocator: std.mem.Allocator, comptime alg: Algorithm, payload: anytype, signatureOptions: SignatureOptions) ![]const u8 {
    var payload_json = std.ArrayList(u8).init(allocator);
    defer payload_json.deinit();

    try std.json.stringify(payload, .{}, payload_json.writer());

    return try encodeMessage(allocator, alg, payload_json.items, signatureOptions);
}

pub fn encodeMessage(allocator: std.mem.Allocator, comptime alg: Algorithm, message: []const u8, signatureOptions: SignatureOptions) ![]const u8 {
    var protected_header = std.json.ObjectMap.init(allocator);
    defer protected_header.deinit();
    try protected_header.put("alg", .{ .string = @tagName(alg) });
    try protected_header.put("typ", .{ .string = "JWT" });
    if (signatureOptions.kid) |kid| {
        try protected_header.put("kid", .{ .string = kid });
    }

    var protected_header_json = std.ArrayList(u8).init(allocator);
    defer protected_header_json.deinit();

    try std.json.stringify(Value{ .object = protected_header }, .{}, protected_header_json.writer());

    const message_base64_len = base64url.Encoder.calcSize(message.len);
    const protected_header_base64_len = base64url.Encoder.calcSize(protected_header_json.items.len);

    var jwt_text = std.ArrayList(u8).init(allocator);
    defer jwt_text.deinit();
    try jwt_text.resize(message_base64_len + 1 + protected_header_base64_len);

    const protected_header_base64 = jwt_text.items[0..protected_header_base64_len];
    const message_base64 = jwt_text.items[protected_header_base64_len + 1 ..][0..message_base64_len];

    _ = base64url.Encoder.encode(protected_header_base64, protected_header_json.items);
    jwt_text.items[protected_header_base64_len] = '.';
    _ = base64url.Encoder.encode(message_base64, message);

    const signature = &generate_signature(alg, signatureOptions.key, protected_header_base64, message_base64);
    const signature_base64_len = base64url.Encoder.calcSize(signature.len);

    try jwt_text.resize(message_base64_len + 1 + protected_header_base64_len + 1 + signature_base64_len);
    const signature_base64 = jwt_text.items[message_base64_len + 1 + protected_header_base64_len + 1 ..][0..signature_base64_len];

    jwt_text.items[message_base64_len + 1 + protected_header_base64_len] = '.';
    _ = base64url.Encoder.encode(signature_base64, signature);

    return jwt_text.toOwnedSlice();
}

pub fn validate(comptime P: type, allocator: std.mem.Allocator, comptime alg: Algorithm, tokenText: []const u8, signatureOptions: SignatureOptions) !std.json.Parsed(P) {
    const message = try validateMessage(allocator, alg, tokenText, signatureOptions);
    defer allocator.free(message);

    // 10.  Verify that the resulting octet sequence is a UTF-8-encoded
    //      representation of a completely valid JSON object conforming to
    //      RFC 7159 [RFC7159]; let the JWT Claims Set be this JSON object.
    return std.json.parseFromSlice(P, allocator, message, .{ .allocate = .alloc_always });
}

pub fn validateMessage(allocator: std.mem.Allocator, comptime expectedAlg: Algorithm, tokenText: []const u8, signatureOptions: SignatureOptions) ![]const u8 {
    // 1.   Verify that the JWT contains at least one period ('.')
    //      character.
    // 2.   Let the Encoded JOSE Header be the portion of the JWT before the
    //      first period ('.') character.
    const end_of_jose_base64 = std.mem.indexOfScalar(u8, tokenText, '.') orelse return error.InvalidFormat;
    const jose_base64 = tokenText[0..end_of_jose_base64];

    // 3.   Base64url decode the Encoded JOSE Header following the
    //      restriction that no line breaks, whitespace, or other additional
    //      characters have been used.
    const jose_json = try allocator.alloc(u8, try base64url.Decoder.calcSizeForSlice(jose_base64));
    defer allocator.free(jose_json);
    try base64url.Decoder.decode(jose_json, jose_base64);

    // 4.   Verify that the resulting octet sequence is a UTF-8-encoded
    //      representation of a completely valid JSON object conforming to
    //      RFC 7159 [RFC7159]; let the JOSE Header be this JSON object.

    // TODO: Make sure the JSON parser confirms everything above

    const cty_opt = @as(?[]const u8, null);
    defer if (cty_opt) |cty| allocator.free(cty);

    var jwt_tree = try std.json.parseFromSlice(std.json.Value, allocator, jose_json, .{});
    defer jwt_tree.deinit();

    // 5.   Verify that the resulting JOSE Header includes only parameters
    //      and values whose syntax and semantics are both understood and
    //      supported or that are specified as being ignored when not
    //      understood.

    var jwt_root = jwt_tree.value;
    if (jwt_root != .object) return error.InvalidFormat;

    {
        const alg_val = jwt_root.object.get("alg") orelse return error.InvalidFormat;
        if (alg_val != .string) return error.InvalidFormat;
        const alg = std.meta.stringToEnum(Algorithm, alg_val.string) orelse return error.InvalidAlgorithm;

        // Make sure that the algorithm matches: https://auth0.com/blog/critical-vulnerabilities-in-json-web-token-libraries/
        if (alg != expectedAlg) return error.InvalidAlgorithm;

        // TODO: Determine if "jku"/"jwk" need to be parsed and validated

        if (jwt_root.object.get("crit")) |crit_val| {
            if (crit_val != .array) return error.InvalidFormat;
            const crit = crit_val.array;
            if (crit.items.len == 0) return error.InvalidFormat;

            // TODO: Implement or allow extensions?
            return error.UnknownExtension;
        }
    }

    // 6.   Determine whether the JWT is a JWS or a JWE using any of the
    //      methods described in Section 9 of [JWE].

    const jwt_type = determine_jwt_type: {
        // From Section 9 of the JWE specification:
        // > o  If the object is using the JWS Compact Serialization or the JWE
        // >    Compact Serialization, the number of base64url-encoded segments
        // >    separated by period ('.') characters differs for JWSs and JWEs.
        // >    JWSs have three segments separated by two period ('.') characters.
        // >    JWEs have five segments separated by four period ('.') characters.
        switch (std.mem.count(u8, tokenText, ".")) {
            2 => break :determine_jwt_type JWTType.JWS,
            4 => break :determine_jwt_type JWTType.JWE,
            else => return error.InvalidFormat,
        }
    };

    // 7.   Depending upon whether the JWT is a JWS or JWE, there are two
    //      cases:
    const message_base64 = get_message: {
        switch (jwt_type) {
            // If the JWT is a JWS, follow the steps specified in [JWS] for
            // validating a JWS.  Let the Message be the result of base64url
            // decoding the JWS Payload.
            .JWS => {
                var section_iter = std.mem.splitScalar(u8, tokenText, '.');
                std.debug.assert(section_iter.next() != null);
                const payload_base64 = section_iter.next().?;
                const signature_base64 = section_iter.rest();

                const signature = try allocator.alloc(u8, try base64url.Decoder.calcSizeForSlice(signature_base64));
                defer allocator.free(signature);
                try base64url.Decoder.decode(signature, signature_base64);

                const gen_sig = &generate_signature(expectedAlg, signatureOptions.key, jose_base64, payload_base64);
                if (!std.mem.eql(u8, signature, gen_sig)) {
                    return error.InvalidSignature;
                }

                break :get_message try allocator.dupe(u8, payload_base64);
            },
            .JWE => {
                // Else, if the JWT is a JWE, follow the steps specified in
                // [JWE] for validating a JWE.  Let the Message be the resulting
                // plaintext.
                return error.Unimplemented;
            },
        }
    };
    defer allocator.free(message_base64);

    // 8.   If the JOSE Header contains a "cty" (content type) value of
    //      "JWT", then the Message is a JWT that was the subject of nested
    //      signing or encryption operations.  In this case, return to Step
    //      1, using the Message as the JWT.
    if (jwt_root.object.get("cty")) |cty_val| {
        if (cty_val != .string) return error.InvalidFormat;
        return error.Unimplemented;
    }

    // 9.   Otherwise, base64url decode the Message following the
    //      restriction that no line breaks, whitespace, or other additional
    //      characters have been used.
    const message = try allocator.alloc(u8, try base64url.Decoder.calcSizeForSlice(message_base64));
    errdefer allocator.free(message);
    try base64url.Decoder.decode(message, message_base64);

    return message;
}

pub fn generate_signature(comptime algo: Algorithm, key: []const u8, protectedHeaderBase64: []const u8, payloadBase64: []const u8) [algo.CryptoFn().mac_length]u8 {
    const T = algo.CryptoFn();
    var h = T.init(key);
    h.update(protectedHeaderBase64);
    h.update(".");
    h.update(payloadBase64);

    var out: [T.mac_length]u8 = undefined;
    h.final(&out);

    return out;
}

