package com.example;

import com.google.cloud.functions.HttpFunction;
import com.google.cloud.functions.HttpRequest;
import com.google.cloud.functions.HttpResponse;

/** Returns a (static) daily report. Only the reporting group may call it. */
public class Reports implements HttpFunction {
  @Override
  public void service(HttpRequest request, HttpResponse response) throws Exception {
    response.setContentType("text/csv");
    response.getWriter().write("day,orders\n2026-10-01,42\n");
  }
}
