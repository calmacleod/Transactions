# Spinel deliberately omits Unicode normalization tables. ICU supplies NFKD.
module NativeUnicode
  ffi_lib 'icuuc'
  ffi_cflags '-I/opt/homebrew/opt/icu4c/include'
  ffi_source <<~C
    #include <unicode/unorm2.h>
    #include <unicode/ustring.h>
    #include <stdlib.h>
    #include <string.h>
    #include <limits.h>

    const char *transactions_nfkd(const char *source) {
      static _Thread_local char *output;
      static _Thread_local size_t capacity;
      if (!source) return NULL;
      size_t bytes = strlen(source);
      if (bytes > INT32_MAX) return NULL;
      UErrorCode status = U_ZERO_ERROR;
      int32_t length = 0;
      u_strFromUTF8(NULL, 0, &length, source, (int32_t)bytes, &status);
      if (status != U_BUFFER_OVERFLOW_ERROR && U_FAILURE(status)) return NULL;
      UChar *input = malloc(((size_t)length + 1) * sizeof(UChar));
      if (!input) return NULL;
      status = U_ZERO_ERROR;
      u_strFromUTF8(input, length + 1, NULL, source, (int32_t)bytes, &status);
      const UNormalizer2 *normalizer = unorm2_getNFKDInstance(&status);
      if (U_FAILURE(status)) { free(input); return NULL; }
      int32_t normalized_length = unorm2_normalize(normalizer, input, length, NULL, 0, &status);
      if (status != U_BUFFER_OVERFLOW_ERROR && U_FAILURE(status)) { free(input); return NULL; }
      UChar *normalized = malloc(((size_t)normalized_length + 1) * sizeof(UChar));
      if (!normalized) { free(input); return NULL; }
      status = U_ZERO_ERROR;
      unorm2_normalize(normalizer, input, length, normalized, normalized_length + 1, &status);
      free(input);
      if (U_FAILURE(status)) { free(normalized); return NULL; }
      int32_t result_length = 0;
      u_strToUTF8(NULL, 0, &result_length, normalized, normalized_length, &status);
      if (status != U_BUFFER_OVERFLOW_ERROR && U_FAILURE(status)) { free(normalized); return NULL; }
      if ((size_t)result_length + 1 > capacity) {
        char *replacement = realloc(output, (size_t)result_length + 1);
        if (!replacement) { free(normalized); return NULL; }
        output = replacement;
        capacity = (size_t)result_length + 1;
      }
      status = U_ZERO_ERROR;
      u_strToUTF8(output, (int32_t)capacity, NULL, normalized, normalized_length, &status);
      free(normalized);
      return U_FAILURE(status) ? NULL : output;
    }
  C
  ffi_func :transactions_nfkd, [:str], :str

  def self.nfkd(value)
    normalized = NativeUnicode.transactions_nfkd(value)
    raise ArgumentError, 'Invalid Unicode merchant description' if normalized.nil?
    normalized.dup
  end
end
